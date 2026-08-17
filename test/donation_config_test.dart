import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/core/donation_config.dart';

void main() {
  test('the default build points at the sponsors page', () {
    // Tests run without --dart-define, so this is the default build. The
    // settings section keys off `isConfigured`, so a typo here would silently
    // hide the section in every release.
    expect(DonationConfig.url, 'https://github.com/sponsors/knoxxr');
    expect(DonationConfig.isConfigured, isTrue);
  });

  test('the default URL survives the usability check', () {
    // Guards against a future edit putting a mailto: or scheme-less value in
    // `defaultValue`, which would render a button that opens nothing.
    expect(DonationConfig.hasUsableUrl(DonationConfig.url), isTrue);
  });

  group('hasUsableUrl', () {
    test('accepts a real donation page', () {
      expect(DonationConfig.hasUsableUrl('https://github.com/sponsors/knoxxr'),
          isTrue);
      expect(DonationConfig.hasUsableUrl('http://example.com/tip'), isTrue);
      expect(DonationConfig.hasUsableUrl('  https://ko-fi.com/x  '), isTrue);
    });

    test('rejects values that would open nothing', () {
      // Each of these would otherwise render a button that silently fails.
      expect(DonationConfig.hasUsableUrl(''), isFalse);
      expect(DonationConfig.hasUsableUrl('   '), isFalse);
      expect(DonationConfig.hasUsableUrl('not a url'), isFalse);
      expect(DonationConfig.hasUsableUrl('ko-fi.com/x'), isFalse,
          reason: 'no scheme');
      expect(DonationConfig.hasUsableUrl('https://'), isFalse,
          reason: 'no host');
    });

    test('rejects non-web schemes', () {
      // A donation link must go to a payment page in a browser, not launch
      // something else on the device.
      expect(DonationConfig.hasUsableUrl('mailto:me@example.com'), isFalse);
      expect(DonationConfig.hasUsableUrl('file:///etc/passwd'), isFalse);
      expect(DonationConfig.hasUsableUrl('javascript:alert(1)'), isFalse);
    });
  });
}
