import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../application/sessions.dart';
import '../../application/settings.dart';
import '../../application/ssh_terminal_controller.dart';
import '../../domain/entities/ssh_connection_request.dart';
import 'remote_files_sheet.dart';
import 'terminal_palettes.dart';
import 'terminal_toolbar.dart';

/// On desktop/web, printable characters arrive as hardware key events; xterm's
/// default text-input path only feeds them via the platform IME (mobile). So
/// desktop uses hardware-keyboard mode; mobile keeps the soft keyboard.
final bool _useHardwareKeyboard = kIsWeb ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.linux;

/// Renders a single [TerminalSession]: its live terminal, connection status,
/// reconnect banner, and the special-key toolbar.
///
/// The [TerminalView] is built ONCE (outside the status [AnimatedBuilder]) and
/// keeps a dedicated [FocusNode], so status changes during connect don't
/// rebuild it or steal keyboard focus. Focus is (re)requested whenever a
/// connection becomes ready.
/// Copy/paste keys for Windows, Linux and Android hardware keyboards.
///
/// xterm's defaults bind Ctrl+A to select-all, which swallows the shell's
/// "start of line" (^A) — one of the most used readline keys. Terminals use
/// Ctrl+Shift for their own actions, so that is where select-all and copy go.
/// Ctrl+V keeps pasting, as Windows users expect. Apple platforms keep the
/// library defaults (⌘C/⌘V/⌘A), which never collide with the shell.
final Map<ShortcutActivator, Intent>? _terminalShortcuts =
    defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.iOS
        ? null
        : {
            const SingleActivator(
              LogicalKeyboardKey.keyC,
              control: true,
              shift: true,
            ): CopySelectionTextIntent.copy,
            const SingleActivator(
              LogicalKeyboardKey.keyV,
              control: true,
              shift: true,
            ): const PasteTextIntent(SelectionChangedCause.keyboard),
            const SingleActivator(LogicalKeyboardKey.keyV, control: true):
                const PasteTextIntent(SelectionChangedCause.keyboard),
            const SingleActivator(
              LogicalKeyboardKey.keyA,
              control: true,
              shift: true,
            ): const SelectAllTextIntent(SelectionChangedCause.keyboard),
          };

const _defaultFontSize = 14.0;

class TerminalSessionView extends ConsumerStatefulWidget {
  const TerminalSessionView({
    required this.session,
    this.accent = Colors.teal,
    this.active = false,
    super.key,
  });

  final TerminalSession session;

  /// Per-session accent (matches the tab), used for the target-host header and
  /// terminal border so the active connection is unmistakable.
  final Color accent;

  /// Whether this is the currently selected tab. When it flips to true the
  /// terminal grabs keyboard focus so the user can type immediately.
  final bool active;

  @override
  ConsumerState<TerminalSessionView> createState() =>
      _TerminalSessionViewState();
}

class _TerminalSessionViewState extends ConsumerState<TerminalSessionView> {
  final _focusNode = FocusNode(debugLabel: 'terminal');

  SshTerminalController get _controller => widget.session.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStatusChanged);
  }

  @override
  void didUpdateWidget(TerminalSessionView old) {
    super.didUpdateWidget(old);
    // Reconnect swaps in a new controller for the same session id.
    if (old.session.controller != _controller) {
      old.session.controller.removeListener(_onStatusChanged);
      _controller.addListener(_onStatusChanged);
    }
    // Became the selected tab → focus so typing goes here right away.
    if (!old.active && widget.active) _focusTerminal();
  }

  /// Ctrl (⌘ on Apple) with = / - / 0 makes the text larger, smaller, or the
  /// default size — the same keys as browsers and editors.
  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? keyboard.isMetaPressed
        : keyboard.isControlPressed;
    if (!modifier || keyboard.isAltPressed) return KeyEventResult.ignored;

    final key = event.logicalKey;
    final settings = ref.read(settingsProvider.notifier);
    final size = ref.read(settingsProvider).fontSize;
    if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add ||
        key == LogicalKeyboardKey.numpadAdd) {
      settings.setFontSize(size + 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      settings.setFontSize(size - 1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) {
      settings.setFontSize(_defaultFontSize);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onStatusChanged() {
    // Only the visible tab may claim focus: several sessions can come up at
    // once (e.g. every tab redialling after the app returns from the
    // background), and a hidden one grabbing focus would send typing there.
    if (widget.active && _controller.status == SshConnectionStatus.connected) {
      _focusTerminal();
    }
  }

  void _focusTerminal() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_onStatusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(settingsProvider.select((s) => s.fontSize));
    final palette = TerminalPalette.byId(
      ref.watch(settingsProvider.select((s) => s.terminalPaletteId)),
    );

    return Column(
      children: [
        _TargetHeader(
          request: widget.session.request,
          accent: widget.accent,
          onOpenFiles: _openFiles,
        ),
        // Only the status strip rebuilds on connection-state changes.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            switch (_controller.status) {
              case SshConnectionStatus.connecting:
                return const LinearProgressIndicator(minHeight: 2);
              case SshConnectionStatus.failed:
                return _ReconnectBanner(
                  message: _controller.errorMessage ?? 'Connection failed',
                  onReconnect: _reconnect,
                );
              case SshConnectionStatus.closed:
                return _ReconnectBanner(
                  message: 'Disconnected.',
                  onReconnect: _reconnect,
                );
              case SshConnectionStatus.idle:
              case SshConnectionStatus.connected:
                return const SizedBox.shrink();
            }
          },
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              // Must match the terminal's own background, or the inset padding
              // below shows as a stripe in a different colour.
              color: palette.theme.background,
              border: Border(
                left: BorderSide(color: widget.accent, width: 3),
              ),
            ),
            // Small dark inset (terminal background) so the top row — which
            // xterm renders partially when the height isn't an exact multiple
            // of the line height — doesn't butt up against the header and look
            // like it overlaps it.
            padding: const EdgeInsets.only(top: 6),
            child: _PinchToZoom(
              fontSize: fontSize,
              onChanged: (size) =>
                  ref.read(settingsProvider.notifier).setFontSize(size),
              child: TerminalView(
                _controller.terminal,
                focusNode: _focusNode,
                autofocus: true,
                hardwareKeyboardOnly: _useHardwareKeyboard,
                theme: palette.theme,
                textStyle: TerminalStyle(fontSize: fontSize),
                shortcuts: _terminalShortcuts,
                onKeyEvent: _onKeyEvent,
              ),
            ),
          ),
        ),
        // Toolbar sends keys programmatically; exclude it from focus traversal
        // so tapping a key never steals keyboard focus from the terminal.
        ExcludeFocus(child: TerminalToolbar(terminal: _controller.terminal)),
      ],
    );
  }

  void _reconnect() =>
      ref.read(sessionsProvider.notifier).reconnect(widget.session.id);

  /// Opens file transfer on this session's live connection.
  Future<void> _openFiles() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final sftp = await _controller.openFiles();
      if (sftp == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Connect first to browse files.')),
        );
        return;
      }
      try {
        if (!navigator.mounted) return;
        await showRemoteFiles(
          navigator.context,
          sftp: sftp,
          title: widget.session.request.displayName,
        );
      } finally {
        // Release the channel; a failure here only means the link is gone.
        sftp.close().ignore();
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not open files: $e')),
      );
    }
  }
}

/// Always-visible bar naming the host this terminal is connected to, tinted
/// with the session's accent color — so it is clear which host you're typing
/// to when several tabs are open.
class _TargetHeader extends StatelessWidget {
  const _TargetHeader({
    required this.request,
    required this.accent,
    required this.onOpenFiles,
  });

  final SshConnectionRequest request;
  final Color accent;

  /// Opens the remote file browser for this connection.
  final VoidCallback onOpenFiles;

  @override
  Widget build(BuildContext context) {
    final target = request.username.isEmpty
        ? '${request.host}:${request.port}'
        : '${request.username}@${request.host}:${request.port}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.16),
        border: Border(
          left: BorderSide(color: accent, width: 4),
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: accent),
          const SizedBox(width: 8),
          Text(
            request.displayName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              target,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          // Sits in the header rather than the key toolbar: it belongs to the
          // connection, not to typing, and here it is visible without scrolling.
          IconButton(
            tooltip: 'Browse files on this server',
            icon: const Icon(Icons.folder_outlined, size: 18),
            visualDensity: VisualDensity.compact,
            onPressed: onOpenFiles,
          ),
        ],
      ),
    );
  }
}

class _ReconnectBanner extends StatelessWidget {
  const _ReconnectBanner({required this.message, required this.onReconnect});

  final String message;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return MaterialBanner(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      leading: const Icon(Icons.info_outline),
      content: Text(message),
      actions: [
        TextButton.icon(
          onPressed: onReconnect,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

/// Two-finger pinch on the terminal changes the text size.
///
/// Listens to raw pointers instead of joining the gesture arena, so the
/// terminal keeps its own scrolling and selection gestures untouched.
class _PinchToZoom extends StatefulWidget {
  const _PinchToZoom({
    required this.fontSize,
    required this.onChanged,
    required this.child,
  });

  final double fontSize;
  final ValueChanged<double> onChanged;
  final Widget child;

  @override
  State<_PinchToZoom> createState() => _PinchToZoomState();
}

class _PinchToZoomState extends State<_PinchToZoom> {
  final Map<int, Offset> _touches = {};
  double? _startDistance;
  double _startSize = _defaultFontSize;

  double _distance() {
    final points = _touches.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _onDown(PointerDownEvent e) {
    if (e.kind != PointerDeviceKind.touch) return;
    _touches[e.pointer] = e.position;
    if (_touches.length == 2) {
      _startDistance = _distance();
      _startSize = widget.fontSize;
    } else {
      _startDistance = null; // Three fingers: not a pinch.
    }
  }

  void _onMove(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.position;
    final start = _startDistance;
    if (_touches.length != 2 || start == null || start < 1) return;
    final size =
        (_startSize * _distance() / start).clamp(8.0, 28.0).roundToDouble();
    if (size != widget.fontSize) widget.onChanged(size);
  }

  void _onEnd(PointerEvent e) {
    _touches.remove(e.pointer);
    if (_touches.length < 2) _startDistance = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onEnd,
        onPointerCancel: _onEnd,
        child: widget.child,
      );
}
