import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_providers.dart';

/// Where people reach the maintainer, instead of an in-app mail form: replies
/// are visible to everyone with the same question, and no mail relay or
/// destination address has to be kept running.
///
/// Bugs go to Issues (something to fix); questions and ideas go to
/// Discussions (a conversation), so the issue list stays a to-do list.
const kIssuesUrl = 'https://github.com/MinaryHub/Kerminal/issues';
const kDiscussionsUrl = 'https://github.com/MinaryHub/Kerminal/discussions';

/// Slug of the Q&A category GitHub creates when Discussions is enabled.
const kQuestionCategory = 'q-a';

/// Short platform label added to a new issue, so a report is actionable
/// without asking what the sender was running.
String currentPlatformLabel() {
  if (kIsWeb) return 'web';
  return defaultTargetPlatform.name.toLowerCase();
}

/// `version+build` of the running app, or null while it is still loading.
final appVersionLabelProvider = Provider<String?>((ref) {
  final info = ref.watch(packageInfoProvider).asData?.value;
  return info == null ? null : '${info.version}+${info.buildNumber}';
});

const _publicNotice = '<!-- This is public. Do not include passwords, keys, '
    'server addresses or email addresses. -->';

String _environment(String? appVersion, String? platform) =>
    'App: ${appVersion ?? 'unknown'} · Platform: ${platform ?? 'unknown'}';

/// A "new issue" link for a bug report, with the environment filled in.
///
/// Issues are public, so the template says so up front and asks for nothing
/// beyond the app version and platform.
Uri newIssueUri({String? appVersion, String? platform}) {
  final body = StringBuffer()
    ..writeln(_publicNotice)
    ..writeln()
    ..writeln('**What happened?**')
    ..writeln()
    ..writeln()
    ..writeln('**Steps to reproduce**')
    ..writeln()
    ..writeln()
    ..writeln('---')
    ..writeln(_environment(appVersion, platform));
  return Uri.parse('$kIssuesUrl/new')
      .replace(queryParameters: {'body': body.toString()});
}

/// A "new discussion" link in the Q&A category for questions and ideas.
Uri newDiscussionUri({String? appVersion, String? platform}) {
  final body = StringBuffer()
    ..writeln(_publicNotice)
    ..writeln()
    ..writeln()
    ..writeln('---')
    ..writeln(_environment(appVersion, platform));
  return Uri.parse('$kDiscussionsUrl/new').replace(queryParameters: {
    'category': kQuestionCategory,
    'body': body.toString(),
  });
}
