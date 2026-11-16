/// One host entry recovered from an OpenSSH `config` file.
class SshConfigHost {
  const SshConfigHost({
    required this.alias,
    required this.hostname,
    required this.port,
    required this.username,
    this.identityFile,
    this.proxyJump,
  });

  /// The name after `Host` — what the user types as `ssh <alias>`.
  final String alias;

  /// `HostName`, falling back to [alias] when the file omits it (which is the
  /// common shorthand for `Host example.com`).
  final String hostname;
  final int port;

  /// `User`, empty when unset — the app then falls back to the OS user.
  final String username;

  /// `IdentityFile` path, kept only to tell the user which key to supply. The
  /// key itself is never read from disk here.
  final String? identityFile;

  /// `ProxyJump` target, kept for display: Kerminal cannot use it yet, so an
  /// entry that needs it must be flagged rather than silently imported as a
  /// direct connection that will not work.
  final String? proxyJump;

  bool get needsJumpHost => proxyJump != null && proxyJump!.isNotEmpty;
}

/// Parses an OpenSSH client config into importable hosts.
///
/// Deliberately partial: it understands the directives that map onto a Kerminal
/// host and ignores the rest, rather than pretending to implement ssh_config.
/// Notably it does **not** expand `Include`, and skips patterns (`Host *`,
/// `web-*`) because those are defaults for other entries, not connectable
/// servers.
class SshConfigParser {
  const SshConfigParser();

  /// Directives are case-insensitive in OpenSSH, and `key value` may be
  /// separated by whitespace or `=`.
  static final _separator = RegExp(r'[\s=]+');

  List<SshConfigHost> parse(String content) {
    final hosts = <SshConfigHost>[];

    // Values that apply to the block currently being read.
    List<String>? aliases;
    String? hostname;
    String? port;
    String? user;
    String? identityFile;
    String? proxyJump;

    void flush() {
      // Values are always dropped at a block boundary, even when the block was
      // a `Match` or the directives came before the first `Host`: otherwise
      // they leaked into the next `Host` entry.
      final blockAliases = aliases;
      final blockHostname = hostname;
      final blockPort = port;
      final blockUser = user;
      final blockIdentity = identityFile;
      final blockJump = proxyJump;
      aliases = null;
      hostname = port = user = identityFile = proxyJump = null;
      if (blockAliases == null) return;

      // A missing, junk or out-of-range port falls back to the default rather
      // than saving a host that can never connect.
      final rawPort = int.tryParse(blockPort ?? '');
      final parsedPort =
          rawPort != null && rawPort >= 1 && rawPort <= 65535 ? rawPort : 22;

      for (final alias in blockAliases) {
        // `Host *` and other patterns set defaults for real entries, and
        // `!name` excludes a host from the block; importing either would
        // create hosts nobody can connect to.
        if (alias.contains('*') ||
            alias.contains('?') ||
            alias.startsWith('!')) {
          continue;
        }
        final resolved = (blockHostname ?? alias).trim();
        if (resolved.isEmpty) continue;
        hosts.add(
          SshConfigHost(
            alias: alias,
            hostname: resolved,
            port: parsedPort,
            username: (blockUser ?? '').trim(),
            identityFile: blockIdentity?.trim(),
            proxyJump: blockJump?.trim(),
          ),
        );
      }
    }

    for (final raw in content.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split(_separator);
      if (parts.length < 2) continue;
      final key = parts.first.toLowerCase();
      final value = parts.skip(1).join(' ').trim();
      if (value.isEmpty) continue;

      // As in OpenSSH, the first value given for a directive wins.
      switch (key) {
        case 'host':
          // A new block ends the previous one.
          flush();
          aliases = parts.skip(1).where((a) => a.isNotEmpty).toList();
        case 'match':
          // Conditional blocks depend on runtime state we cannot evaluate;
          // ending the current block stops their directives leaking into it.
          flush();
        case 'hostname':
          hostname ??= _unquote(value);
        case 'port':
          port ??= value;
        case 'user':
          user ??= _unquote(value);
        case 'identityfile':
          identityFile ??= _unquote(value);
        case 'proxyjump':
          proxyJump ??= _unquote(value);
      }
    }
    flush();
    return hosts;
  }

  String _unquote(String value) {
    if (value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")))) {
      return value.substring(1, value.length - 1);
    }
    return value;
  }
}
