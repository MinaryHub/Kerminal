import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/core/donation_config.dart';

void main() {
  test('the default build ships no donation link yet', () {
    // The project moved to the MinaryHub organization so that no personal
    // handle is published; the org cannot accept sponsorships yet, so the
    // section is deliberately hidden. Flipping `defaultValue` back on is a
    // one-line change — this test is what makes that flip deliberate.
    expect(DonationConfig.url, isEmpty);
    expect(DonationConfig.isConfigured, isFalse);
  });

  test('whatever gets configured must survive the usability check', () {
    // Guards the eventual org URL, and any --dart-define, against a mailto: or
    // scheme-less value that would render a button opening nothing.
    expect(
      DonationConfig.hasUsableUrl('https://github.com/sponsors/MinaryHub'),
      isTrue,
    );
  });

  group('hasUsableUrl', () {
    test('accepts a real donation page', () {
      expect(DonationConfig.hasUsableUrl('https://github.com/sponsors/MinaryHub'),
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
