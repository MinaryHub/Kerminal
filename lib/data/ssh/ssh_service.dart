import 'dart:async';
import 'dart:convert';

import 'package:dartssh2/dartssh2.dart';
import 'package:xterm/xterm.dart';

import '../../domain/entities/ssh_connection_request.dart';
import 'sftp_service.dart';

/// Verifies a server's host key. Returns true to accept the connection.
/// [fingerprint] is the OpenSSH `SHA256:...` fingerprint of the host key.
typedef HostKeyVerifier = Future<bool> Function(
  String host,
  int port,
  String keyType,
  String fingerprint,
);

/// One thing the server is asking the user for during keyboard-interactive
/// authentication — typically a one-time code.
class SshPrompt {
  const SshPrompt({required this.text, required this.echo});

  /// The server's prompt, e.g. `Verification code: `.
  final String text;

  /// Whether the typed answer may be shown. False for passwords.
  final bool echo;
}

/// Answers a server's keyboard-interactive challenge (2FA/OTP, expired
/// password, …). Returns one answer per prompt in order, or null to give up.
///
/// Mirrors dartssh2's handler but in the app's own types, so presentation code
/// can build the dialog without importing the SSH library.
typedef SshUserInfoResponder = Future<List<String>?> Function(
  String name,
  String instruction,
  List<SshPrompt> prompts,
);

/// A live SSH shell bound to an [xterm] [Terminal].
///
/// [connect] establishes the transport, authenticates, opens a PTY-backed
/// shell and wires it bidirectionally to the terminal. It completes only once
/// authentication succeeds; any failure throws so the caller can surface it.
class SshSession {
  SshSession._(this._client, this._session);

  final SSHClient _client;
  final SSHSession _session;

  /// Completes when the connection is torn down (remote close, error, or
  /// [close]). Ending the shell (`exit`) also completes it: the client is
  /// closed as soon as the shell channel ends.
  Future<void> get done => _client.done;

  /// The remote shell's exit status, once it has exited normally.
  int? get exitCode => _session.exitCode;

  static Future<SshSession> connect({
    required Terminal terminal,
    required SshConnectionRequest request,
    HostKeyVerifier? verifyHostKey,
    SshUserInfoResponder? respondToPrompts,
    Duration timeout = const Duration(seconds: 15),
    // How long the server may go without progress during key exchange and
    // login. Time spent waiting for the user (host-key or 2FA dialogs) is not
    // counted, so a slow answer never aborts the login.
    Duration loginTimeout = const Duration(seconds: 30),
    // Mobile carriers and NAT gateways drop idle TCP flows within a minute or
    // so, which is exactly what happens while the app sits in the background.
    Duration keepAliveInterval = const Duration(seconds: 20),
  }) async {
    // Parse the key before dialling: a wrong passphrase or a bad key must not
    // leave an open socket behind, and deserves a message the user can act on.
    final identities = request.authKind == SshAuthKind.key
        ? _parseKey(request.privateKeyPem, request.passphrase)
        : null;

    // Login watchdog. dartssh2's own handshake/auth timeouts also run while a
    // host-key or 2FA dialog is open, so they would abort a user who is simply
    // reading the prompt. This one is paused for the duration of each dialog.
    final stalled = Completer<void>();
    Timer? watchdog;
    var waitingOnUser = 0;
    void arm() {
      watchdog?.cancel();
      if (waitingOnUser > 0 || stalled.isCompleted) return;
      watchdog = Timer(loginTimeout, () {
        if (!stalled.isCompleted) stalled.complete();
      });
    }

    Future<T> askUser<T>(Future<T> Function() ask) async {
      waitingOnUser++;
      watchdog?.cancel();
      try {
        return await ask();
      } finally {
        waitingOnUser--;
        arm();
      }
    }

    final socket = await SSHSocket.connect(
      request.host,
      request.port,
      timeout: timeout,
    );

    final client = SSHClient(
      socket,
      username: request.username,
      keepAliveInterval: keepAliveInterval,
      // dartssh2 passes (keyType, fingerprintBytes); the fingerprint is the
      // OpenSSH "SHA256:..." string.
      //
      // With no verifier the connection is refused rather than trusting any
      // key: every call site supplies one, and a future caller forgetting it
      // should fail loudly instead of silently losing MITM protection.
      onVerifyHostKey: verifyHostKey == null
          ? (type, fingerprint) => false
          : (type, fingerprint) => askUser(
                () => verifyHostKey(
                  request.host,
                  request.port,
                  type,
                  utf8.decode(fingerprint),
                ),
              ),
      identities: identities,
      onPasswordRequest: request.authKind == SshAuthKind.password
          ? () => request.password ?? ''
          : null,
      // Servers that require a one-time code (or force a password change) use
      // keyboard-interactive. Without a handler those servers simply cannot be
      // reached — authentication fails with no way for the user to answer.
      // The request/prompt types are not exported by dartssh2, so the
      // parameter type comes from its handler typedef by inference.
      onUserInfoRequest: respondToPrompts == null
          ? null
          : (req) => askUser(
                () => respondToPrompts(
                  req.name,
                  req.instruction,
                  [
                    for (final p in req.prompts)
                      SshPrompt(text: p.promptText, echo: p.echo),
                  ],
                ),
              ),
    );

    arm();
    final SSHSession session;
    try {
      await Future.any([
        client.authenticated,
        stalled.future.then<void>(
          (_) => throw TimeoutException(
            'The server stopped responding during login.',
            loginTimeout,
          ),
        ),
      ]);
      watchdog?.cancel();
      session = await client
          .shell(
            pty: SSHPtyConfig(
              width: terminal.viewWidth,
              height: terminal.viewHeight,
            ),
          )
          .timeout(
            timeout,
            onTimeout: () => throw TimeoutException(
              'The server did not open a shell.',
              timeout,
            ),
          );
    } catch (_) {
      watchdog?.cancel();
      client.close();
      rethrow;
    }

    // `exit` ends the shell channel, but OpenSSH keeps the connection itself
    // open, so without this the tab would stay "connected" to nothing.
    // ignore(): a channel error must not surface as an unhandled exception.
    session.done.whenComplete(client.close).ignore();

    // SSH output -> terminal.
    session.stdout
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);
    session.stderr
        .cast<List<int>>()
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(terminal.write);

    // Terminal input -> SSH.
    terminal.onOutput = (data) => session.write(utf8.encode(data));
    terminal.onResize = (w, h, pw, ph) => session.resizeTerminal(w, h, pw, ph);

    return SshSession._(client, session);
  }

  bool get isClosed => _client.isClosed;

  static List<SSHKeyPair> _parseKey(String? pem, String? passphrase) {
    if (pem == null || pem.trim().isEmpty) {
      throw const SshKeyException('No private key is saved for this server.');
    }
    final hasPassphrase = passphrase != null && passphrase.isNotEmpty;
    try {
      return SSHKeyPair.fromPem(pem, hasPassphrase ? passphrase : null);
    } catch (e) {
      var encrypted = false;
      try {
        encrypted = SSHKeyPair.isEncryptedPem(pem);
      } catch (_) {
        // Not a key format we can inspect — report it as unreadable below.
      }
      if (encrypted && !hasPassphrase) {
        throw const SshKeyException(
          'This private key is protected by a passphrase. '
          'Edit the server and enter the passphrase.',
        );
      }
      if (encrypted) {
        throw const SshKeyException(
          'Wrong passphrase for this private key.',
        );
      }
      throw SshKeyException('The private key could not be read: $e');
    }
  }

  /// Opens an SFTP channel on this connection for file transfer.
  ///
  /// Reuses the authenticated session rather than dialling again, so the user is
  /// not asked for credentials (or a 2FA code) a second time.
  Future<SftpService> openSftp() async => SftpService(await _client.sftp());

  /// Round-trips a keep-alive to find out whether the link is *really* alive.
  ///
  /// A socket killed while the app was suspended often looks open from this
  /// side until the next write times out, so [done] may not have fired yet.
  /// Returns false when the server doesn't answer within [timeout].
  Future<bool> isAlive({Duration timeout = const Duration(seconds: 5)}) async {
    if (_client.isClosed) return false;
    try {
      await _client.ping().timeout(timeout);
      return !_client.isClosed;
    } catch (_) {
      return false;
    }
  }

  void close() {
    _session.close();
    _client.close();
  }
}

/// The saved private key could not be used; [message] is safe to show.
class SshKeyException implements Exception {
  const SshKeyException(this.message);
  final String message;
  @override
  String toString() => message;
}
