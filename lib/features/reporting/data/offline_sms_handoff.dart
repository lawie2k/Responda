import 'package:url_launcher/url_launcher.dart';

import 'offline_report_store.dart';

typedef SmsUriLauncher = Future<bool> Function(Uri uri);

class OfflineSmsHandoff {
  OfflineSmsHandoff({SmsUriLauncher? launcher})
    : _launcher = launcher ?? _launchUri;

  static const recipient = '09476236516';

  final SmsUriLauncher _launcher;

  Future<bool> openComposer(SavedOfflineReport report) {
    return _launcher(buildUri(report));
  }

  Uri buildUri(SavedOfflineReport report) {
    return Uri(
      scheme: 'sms',
      path: recipient,
      query: _encodeQueryParameters({'body': buildMessage(report)}),
    );
  }

  String buildMessage(SavedOfflineReport report) {
    final draft = report.draft;
    final landmark = draft.landmark.trim();
    return [
      'RESPONDA EMERGENCY REPORT',
      'Local ID: ${report.id}',
      'Incident: ${draft.incidentType.label}',
      'GPS: ${draft.coordinates}',
      'Accuracy: ${draft.accuracyLabel}',
      if (landmark.isNotEmpty) 'Landmark: $landmark',
      'Time: ${report.savedAt.toIso8601String()}',
      'Details: ${draft.description}',
      'More people need help: ${_yesNo(draft.morePeople)}',
      'Additional assistance: ${_yesNo(draft.additionalAssistance)}',
      'Still dangerous: ${_yesNo(draft.stillDangerous)}',
    ].join('\n');
  }

  static String _yesNo(bool? value) => switch (value) {
    true => 'Yes',
    false => 'No',
    null => 'Not answered',
  };

  static String _encodeQueryParameters(Map<String, String> values) {
    return values.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }

  static Future<bool> _launchUri(Uri uri) => launchUrl(uri);
}
