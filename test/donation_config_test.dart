import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/core/donation_config.dart';

void main() {
  test('an unconfigured build reports no donation page', () {
    // Tests run without --dart-define, so this is the default build. The
    // settings section keys off this: no URL, no section, no dead link.
    expect(DonationConfig.url, isEmpty);
    expect(DonationConfig.isConfigured, isFalse);
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
