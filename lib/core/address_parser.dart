/// A server address typed by hand, e.g. `admin@10.0.0.5:2222`.
class ParsedAddress {
  const ParsedAddress({required this.host, this.port = 22, this.username});

  final String host;
  final int port;

  /// Null when the text named no user.
  final String? username;

  @override
  String toString() =>
      '${username == null ? '' : '$username@'}$host${port == 22 ? '' : ':$port'}';
}

/// Recognises what people paste or type to reach a server:
///
///   host · user@host · host:port · user@host:port · [v6]:port
///   ssh user@host · ssh -p 2222 user@host
///
/// Returns null for anything else — including a bare word like `web`, which is
/// far more likely a search for a saved host than an address.
ParsedAddress? parseAddress(String input) {
  var text = input.trim();
  if (text.isEmpty) return null;

  int? port;
  if (text.startsWith('ssh ')) {
    final parts = text.split(RegExp(r'\s+')).skip(1).toList();
    String? target;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == '-p' && i + 1 < parts.length) {
        port = int.tryParse(parts[++i]);
        if (port == null) return null;
      } else if (parts[i].startsWith('-')) {
        return null; // Other options are not something we can honour here.
      } else if (target == null) {
        target = parts[i];
      } else {
        return null; // A remote command: not a plain address.
      }
    }
    if (target == null) return null;
    text = target;
  }
  if (text.contains(RegExp(r'\s'))) return null;

  String? user;
  final at = text.lastIndexOf('@');
  if (at >= 0) {
    user = text.substring(0, at);
    text = text.substring(at + 1);
    if (user.isEmpty) return null;
  }

  String host;
  if (text.startsWith('[')) {
    // [IPv6]:port
    final close = text.indexOf(']');
    if (close < 0) return null;
    host = text.substring(1, close);
    final rest = text.substring(close + 1);
    if (rest.isNotEmpty) {
      if (!rest.startsWith(':') || port != null) return null;
      port = int.tryParse(rest.substring(1));
      if (port == null) return null;
    }
  } else {
    final colon = text.indexOf(':');
    if (colon >= 0 && colon == text.lastIndexOf(':')) {
      if (port != null) return null;
      port = int.tryParse(text.substring(colon + 1));
      if (port == null) return null;
      host = text.substring(0, colon);
    } else {
      host = text; // No port, or a bare IPv6 address.
    }
  }

  if (host.isEmpty || !RegExp(r'^[A-Za-z0-9._:%-]+$').hasMatch(host)) {
    return null;
  }
  // A bare word with nothing address-like about it is a search term.
  final looksLikeAddress =
      user != null || port != null || host.contains('.') || host.contains(':') ||
          host == 'localhost';
  if (!looksLikeAddress) return null;

  final p = port ?? 22;
  if (p < 1 || p > 65535) return null;
  return ParsedAddress(host: host, port: p, username: user);
}
