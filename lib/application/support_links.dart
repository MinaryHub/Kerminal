import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'update_providers.dart';

/// Where questions, bug reports and requests go. GitHub Issues replaced the
/// in-app mail form: replies are visible to everyone with the same question,
/// and no mail relay or destination address has to be kept running.
const kIssuesUrl = 'https://github.com/MinaryHub/Kerminal/issues';

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

/// A "new issue" link with the environment already filled in.
///
/// Issues are public, so the template says so up front and asks for nothing
/// beyond the app version and platform.
Uri newIssueUri({String? appVersion, String? platform}) {
  final body = StringBuffer()
    ..writeln('<!-- Issues are public. Do not include passwords, keys, '
        'server addresses or email addresses. -->')
    ..writeln()
    ..writeln('**What happened / what would you like?**')
    ..writeln()
    ..writeln()
    ..writeln('**Steps to reproduce (for bugs)**')
    ..writeln()
    ..writeln()
    ..writeln('---')
    ..writeln('App: ${appVersion ?? 'unknown'} · Platform: ${platform ?? 'unknown'}');
  return Uri.parse('$kIssuesUrl/new')
      .replace(queryParameters: {'body': body.toString()});
}
