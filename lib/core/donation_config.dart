/// Where the "support development" link goes.
///
/// Set [url] to a donation page (GitHub Sponsors, Ko-fi, Buy Me a Coffee, Toss,
/// …). While it is empty the whole section is hidden, so an unconfigured build
/// never shows a dead link.
///
/// Can also be supplied at build time without editing this file:
/// `--dart-define=DONATION_URL=https://...`
///
/// **Store policy note (Microsoft Store 10.8.x):** voluntary donations may go
/// through a third-party payment page, but *only* while the donor receives
/// nothing in return. The moment a donation unlocks a feature, removes ads or
/// grants any digital good, the Store's in-app purchase API becomes mandatory.
/// Kerminal is therefore identical whether or not anyone donates — do not tie
/// anything to this.
library;

class DonationConfig {
  const DonationConfig._();

  static const url = String.fromEnvironment(
    'DONATION_URL',
    // Public information, not a secret — fine to hard-code. Left empty until a
    // donation page exists.
    defaultValue: '',
  );

  /// Whether this build has somewhere to send donors.
  static bool get isConfigured => hasUsableUrl(url);

  /// Whether [candidate] is somewhere we can actually send a browser.
  ///
  /// Split out from [isConfigured] so it can be tested: [url] is a compile-time
  /// constant that a test cannot vary. A blank or non-http value would render a
  /// button that opens nothing.
  static bool hasUsableUrl(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty;
  }
}
