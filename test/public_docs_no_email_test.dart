import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Documents published to the *public* repo must not carry a personal address.
///
/// `PRIVACY.md` is the URL submitted to the Microsoft Store and is copied to the
/// public repo on every release, so an address added here becomes permanently
/// public — and it stays in that repo's git history even after removal.
/// [support_links_test] guards `lib/` the same way; this covers the docs.
///
/// A privacy policy still needs a contact route: GitHub Discussions and Issues
/// (Settings → Support opens either) serve that without publishing anyone's
/// address.
void main() {
  test('published docs contain no email address', () {
    // Only files that actually reach the public repo. Internal notes (DEPLOY,
    // PLAN, CHANGELOG) stay in the private repo and are not checked.
    const published = ['PRIVACY.md', 'LICENSE'];
    final email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
    final offenders = <String>[];

    for (final name in published) {
      final file = File(name);
      if (!file.existsSync()) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (email.hasMatch(lines[i])) {
          offenders.add('$name:${i + 1}: ${lines[i].trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Use GitHub Discussions or Issues instead of an address:\n'
          '${offenders.join('\n')}',
    );
  });
}
