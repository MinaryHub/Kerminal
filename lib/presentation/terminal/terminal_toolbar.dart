import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import 'terminal_clipboard.dart';

/// A compact row of hard-to-type keys for the terminal (essential on mobile,
/// handy on desktop).
///
/// Layout is split in two. The keys that carry the most traffic — the Ctrl
/// modifier, command history, completion, escape and paste — are **pinned** and
/// always on screen; everything else scrolls. Before this split the row was one
/// horizontal list in declaration order, which pushed the arrow keys past the
/// right edge of a phone: the single most-used key (history ↑) could only be
/// reached by scrolling.
///
/// Keys reach the shell two ways, and the difference matters:
///   * [Terminal.keyInput] for named keys (arrows, Tab, Esc…), which xterm
///     encodes for us.
///   * [Terminal.onOutput] for literal text. That callback is the one funnel
///     every terminal input passes through on its way to SSH (see
///     `ssh_service.dart`), which is also what makes the Ctrl modifier possible
///     for characters typed on the *soft keyboard* — see [_armCtrl].
class TerminalToolbar extends StatefulWidget {
  const TerminalToolbar({
    required this.terminal,
    this.selection,
    this.onToggleKeyboard,
    super.key,
  });

  /// Shows or hides the on-screen keyboard; null where there is none.
  final VoidCallback? onToggleKeyboard;

  final Terminal terminal;

  /// The terminal's selection. While something is selected a Copy key leads
  /// the bar: phones can select text (long-press) but have no other way to
  /// copy it.
  final TerminalController? selection;

  @override
  State<TerminalToolbar> createState() => _TerminalToolbarState();
}

/// Ctrl has three states, not two. One-shot covers `Ctrl+C`; latched covers
/// holding Ctrl down through a run of keys without re-tapping it each time.
enum _Mod { off, oneShot, latched }

class _TerminalToolbarState extends State<TerminalToolbar> {
  _Mod _ctrl = _Mod.off;

  /// The real output sink, saved while our interceptor is installed in its
  /// place. Null whenever we are not intercepting.
  void Function(String)? _sink;

  /// The interceptor we installed, kept so we can tell "still ours" from
  /// "replaced by a reconnect" before restoring.
  void Function(String)? _installed;

  bool get _ctrlOn => _ctrl != _Mod.off;

  @override
  void initState() {
    super.initState();
    widget.selection?.addListener(_onSelection);
  }

  @override
  void didUpdateWidget(TerminalToolbar old) {
    super.didUpdateWidget(old);
    if (old.selection != widget.selection) {
      old.selection?.removeListener(_onSelection);
      widget.selection?.addListener(_onSelection);
    }
  }

  @override
  void dispose() {
    widget.selection?.removeListener(_onSelection);
    _restoreSink();
    super.dispose();
  }

  bool _hasSelection = false;

  void _onSelection() {
    final has = widget.selection?.selection != null;
    if (has != _hasSelection && mounted) setState(() => _hasSelection = has);
  }

  Future<void> _copy() async {
    final selection = widget.selection;
    if (selection == null) return;
    final messenger = ScaffoldMessenger.of(context);
    if (await copySelection(widget.terminal, selection)) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Copied'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  // ------------------------------------------------------------------ input

  /// Sends literal text straight to the shell, bypassing our own interceptor —
  /// toolbar keys apply Ctrl themselves, so passing through it would apply the
  /// modifier twice.
  void _sendRaw(String text) => (_sink ?? widget.terminal.onOutput)?.call(text);

  /// Ctrl+letter is just the letter with the top three bits cleared: `a` (0x61)
  /// becomes 0x01, `r` becomes 0x12 (^R). The handful of punctuation controls
  /// follow the same table.
  String _toControl(String text) {
    if (text.isEmpty) return text;
    final c = text.codeUnitAt(0);
    if (c >= 0x61 && c <= 0x7a) return String.fromCharCode(c - 0x60); // a–z
    if (c >= 0x41 && c <= 0x5a) return String.fromCharCode(c - 0x40); // A–Z
    if (c == 0x3f) return String.fromCharCode(0x7f); // ^? → DEL
    if (c >= 0x5b && c <= 0x5f) return String.fromCharCode(c - 0x40); // [ \ ] ^ _
    return text; // Nothing sensible to map — send it through unchanged.
  }

  /// Installs a one-use wrapper around [Terminal.onOutput].
  ///
  /// Characters typed on the soft keyboard never pass through this widget —
  /// they go from the platform IME into xterm directly — so a modifier that
  /// only coloured a button could never turn the next keystroke into `Ctrl+R`.
  /// Wrapping the output funnel is what lets it: the next chunk of text on its
  /// way to SSH is converted, then the real sink is put back.
  void _armCtrl() {
    if (_sink != null) return; // already armed
    final original = widget.terminal.onOutput;
    void interceptor(String data) {
      if (!mounted) {
        // Disposed between arming and this keystroke — pass it through
        // untouched rather than reaching for a widget that is gone.
        original?.call(data);
        return;
      }
      _restoreSink();
      original?.call(_toControl(data));
      switch (_ctrl) {
        case _Mod.latched:
          _armCtrl(); // held down — stay armed for the key after this one
        case _Mod.oneShot:
          setState(() => _ctrl = _Mod.off);
        case _Mod.off:
          break;
      }
    }

    _sink = original;
    _installed = interceptor;
    widget.terminal.onOutput = interceptor;
  }

  /// Puts the real sink back, unless a reconnect has already replaced it — in
  /// that case the new one is live and ours is stale, so we leave it alone.
  void _restoreSink() {
    if (_sink == null) return;
    if (identical(widget.terminal.onOutput, _installed)) {
      widget.terminal.onOutput = _sink;
    }
    _sink = null;
    _installed = null;
  }

  void _cycleCtrl() {
    HapticFeedback.selectionClick();
    setState(() {
      switch (_ctrl) {
        case _Mod.off:
          _ctrl = _Mod.oneShot;
          _armCtrl();
        case _Mod.oneShot:
          _ctrl = _Mod.latched; // stays armed
        case _Mod.latched:
          _ctrl = _Mod.off;
          _restoreSink();
      }
    });
  }

  /// Called after a *toolbar* key fires: a one-shot modifier has now been spent.
  void _consumeOneShot() {
    if (_ctrl != _Mod.oneShot) return;
    _restoreSink();
    setState(() => _ctrl = _Mod.off);
  }

  void _tapKey(TerminalKey key) {
    widget.terminal.keyInput(key, ctrl: _ctrlOn);
    _consumeOneShot();
  }

  void _tapText(String text) {
    _sendRaw(_ctrlOn ? _toControl(text) : text);
    _consumeOneShot();
  }

  /// Sends a raw escape sequence (Home/End/PgUp/PgDn). Written out rather than
  /// routed through [TerminalKey] so the set of keys we offer isn't limited to
  /// the enum members this xterm version happens to expose.
  void _tapSeq(String sequence) {
    _sendRaw(sequence);
    _consumeOneShot();
  }

  // ------------------------------------------------------------------ paste

  Future<void> _paste() async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Clipboard is empty.')),
      );
      return;
    }

    // Every newline in a paste runs a command. Pasting a block you only meant
    // to read into a production shell is the kind of mistake that has no undo,
    // so anything multi-line gets confirmed first.
    final lines = text.trimRight().split('\n').length;
    if (lines > 1 && mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Run $lines lines?'),
          content: const Text(
            'This clipboard contains more than one line. Each line runs as a '
            'separate command as soon as it is pasted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Paste'),
            ),
          ],
        ),
      );
      if (go != true) return;
    }
    _sendRaw(text);
  }

  // ----------------------------------------------------------------- layout

  @override
  Widget build(BuildContext context) {
    // Pinned: the keys a session leans on constantly. Ctrl leads because it is
    // the one key that unlocks all the others.
    final pinned = <Widget>[
      _CtrlChip(state: _ctrl, onTap: _cycleCtrl),
      // Ctrl+C is by far the most used combination (stop a command); one tap
      // instead of Ctrl, then the soft keyboard's c.
      _key('^C', 'Stop the running command (Ctrl+C)', () => _tapSeq('\x03')),
      _key('↑', 'Previous command', () => _tapKey(TerminalKey.arrowUp),
          repeat: true),
      _key('↓', 'Next command', () => _tapKey(TerminalKey.arrowDown),
          repeat: true),
      _key('Tab', 'Complete or indent', () => _tapKey(TerminalKey.tab)),
      _key('Esc', 'Escape', () => _tapKey(TerminalKey.escape)),
      // The pinned row is already as wide as a small phone allows, so Copy
      // takes Paste's place while text is selected rather than adding a key.
      if (_hasSelection)
        _icon(Icons.copy, 'Copy selected text', _copy)
      else
        _icon(Icons.content_paste_go, 'Paste from clipboard', _paste),
    ];

    // Scrolling: still useful, but not on the critical path. Cursor movement
    // lives here because tapping the terminal is a workable alternative;
    // history has none.
    final rest = <Widget>[
      if (widget.onToggleKeyboard != null)
        _icon(Icons.keyboard_hide_outlined, 'Show or hide the keyboard',
            widget.onToggleKeyboard!),
      _key('←', 'Left', () => _tapKey(TerminalKey.arrowLeft), repeat: true),
      _key('→', 'Right', () => _tapKey(TerminalKey.arrowRight), repeat: true),
      _key('|', 'Pipe', () => _tapText('|')),
      _key('~', 'Home directory', () => _tapText('~')),
      _key('/', 'Slash', () => _tapText('/')),
      _key('-', 'Dash', () => _tapText('-')),
      _key('Home', 'Start of line', () => _tapSeq('\x1b[H')),
      _key('End', 'End of line', () => _tapSeq('\x1b[F')),
      _key('PgUp', 'Page up', () => _tapSeq('\x1b[5~'), repeat: true),
      _key('PgDn', 'Page down', () => _tapSeq('\x1b[6~'), repeat: true),
    ];

    return Material(
      elevation: 2,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _kBarHeight,
          child: Row(
            children: [
              const SizedBox(width: 8),
              for (final w in pinned) ...[w, const SizedBox(width: 6)],
              VerticalDivider(
                width: 9,
                thickness: 1,
                indent: 8,
                endIndent: 8,
                color: Theme.of(context).dividerColor,
              ),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  itemCount: rest.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, i) => Center(child: rest[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _key(
    String label,
    String tooltip,
    VoidCallback onTap, {
    bool repeat = false,
  }) =>
      _Chip(onTap: onTap, tooltip: tooltip, repeat: repeat, child: Text(label));

  Widget _icon(IconData icon, String tooltip, VoidCallback onTap) =>
      _Chip(onTap: onTap, tooltip: tooltip, child: Icon(icon, size: 20));
}

/// 44 for the keys (the smallest target Apple's guidelines accept; Material
/// asks for 48) plus a little breathing room above and below. The old row was
/// 44 tall *including* padding, which left 32 for the key itself.
const double _kKeySize = 44;
const double _kBarHeight = 58;

/// A toolbar key. Every press gives a light haptic tick: a key on glass has
/// no travel, so without it people press twice to be sure.
///
/// With [repeat], holding the key repeats it like a physical keyboard does,
/// for walking through history or moving the cursor. The tooltip then shows
/// on hover only, since a long-press means "repeat".
class _Chip extends StatefulWidget {
  const _Chip({
    required this.child,
    required this.onTap,
    required this.tooltip,
    this.repeat = false,
  });

  final Widget child;
  final VoidCallback onTap;
  final String tooltip;
  final bool repeat;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  static const _repeatEvery = Duration(milliseconds: 70);
  Timer? _timer;

  void _press() {
    HapticFeedback.selectionClick();
    widget.onTap();
  }

  void _startRepeat() {
    _press();
    _timer?.cancel();
    _timer = Timer.periodic(_repeatEvery, (_) => widget.onTap());
  }

  void _stopRepeat() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopRepeat();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget button = OutlinedButton(
      onPressed: _press,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(_kKeySize, _kKeySize),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        visualDensity: VisualDensity.compact,
      ),
      child: widget.child,
    );
    if (widget.repeat) {
      button = GestureDetector(
        onLongPressStart: (_) => _startRepeat(),
        onLongPressEnd: (_) => _stopRepeat(),
        onLongPressCancel: _stopRepeat,
        child: button,
      );
    }
    return Tooltip(
      message: widget.tooltip,
      // Touch users never hover, so a long-press reveals it — except on keys
      // where a long-press repeats.
      triggerMode: widget.repeat
          ? TooltipTriggerMode.manual
          : TooltipTriggerMode.longPress,
      child: button,
    );
  }
}

/// The Ctrl key, which has to *look* like what it is doing. An armed modifier
/// that isn't obvious sends `c` where the user meant `Ctrl+C` — so the state
/// shows in fill and border, not colour alone, and latched adds a lock icon so
/// it survives a glance in sunlight or with impaired colour vision.
class _CtrlChip extends StatelessWidget {
  const _CtrlChip({required this.state, required this.onTap});

  final _Mod state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latched = state == _Mod.latched;
    final on = state != _Mod.off;

    return Tooltip(
      message: switch (state) {
        _Mod.off => 'Ctrl — tap, then press a key',
        _Mod.oneShot => 'Ctrl applies to the next key — tap again to hold it',
        _Mod.latched => 'Ctrl is held — tap to release',
      },
      triggerMode: TooltipTriggerMode.longPress,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(_kKeySize, _kKeySize),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
          backgroundColor: latched ? scheme.primary : null,
          foregroundColor: latched
              ? scheme.onPrimary
              : on
                  ? scheme.primary
                  : null,
          side: on
              ? BorderSide(color: scheme.primary, width: latched ? 1 : 2)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ctrl'),
            if (latched) ...[
              const SizedBox(width: 3),
              const Icon(Icons.lock, size: 12),
            ],
          ],
        ),
      ),
    );
  }
}
