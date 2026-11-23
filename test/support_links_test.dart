import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kerminal/application/support_links.dart';

void main() {
  test('currentPlatformLabel returns a non-empty lowercase label', () {
    final label = currentPlatformLabel();
    expect(label, isNotEmpty);
    expect(label, label.toLowerCase());
  });

  test('new issue link targets the repository and carries the environment', () {
    final uri = newIssueUri(appVersion: '1.6.1+57', platform: 'android');
    expect(uri.toString(), startsWith('$kIssuesUrl/new?'));
    final body = uri.queryParameters['body']!;
    expect(body, contains('App: 1.6.1+57'));
    expect(body, contains('Platform: android'));
    expect(body, contains('This is public'));
  });

  test('new discussion link opens the Q&A category with the environment', () {
    final uri = newDiscussionUri(appVersion: '1.6.2+58', platform: 'windows');
    expect(uri.toString(), startsWith('$kDiscussionsUrl/new?'));
    expect(uri.queryParameters['category'], kQuestionCategory);
    final body = uri.queryParameters['body']!;
    expect(body, contains('App: 1.6.2+58'));
    expect(body, contains('Platform: windows'));
    expect(body, contains('This is public'));
  });

  test('unknown environment is stated rather than left blank', () {
    final body = newIssueUri().queryParameters['body']!;
    expect(body, contains('App: unknown'));
    expect(body, contains('Platform: unknown'));
  });

  // The app is public, so a bundled address or `mailto:` link would hand it to
  // anyone who installs it or reads this repository. Contact goes through
  // GitHub Issues; keep it that way.
  test('no email address or mailto: link is embedded in the app', () {
    final offenders = <String>[];
    final email = RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+');
    final mailto = RegExp(r'mailto:', caseSensitive: false);

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Doc comments legitimately mention addresses (e.g. example.com).
        if (line.trimLeft().startsWith('//')) continue;
        if (email.hasMatch(line) || mailto.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'No contact addresses in the app:\n${offenders.join('\n')}',
    );
  });
}
