import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/app_strings.dart';
import 'offline_report_store.dart';

typedef SmsUriLauncher = Future<bool> Function(Uri uri);

class OfflineSmsHandoff {
  OfflineSmsHandoff({SmsUriLauncher? launcher, AppStrings? strings})
    : _launcher = launcher ?? _launchUri,
      _strings = strings ?? const AppStrings(AppLanguage.english);

  static const recipient = '09476236516';

  final SmsUriLauncher _launcher;
  final AppStrings _strings;

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
    final accuracy = draft.locationAccuracy == null
        ? _strings.text('Accuracy unavailable')
        : '±${draft.locationAccuracy!.round()} m ${_strings.text('accuracy')}';
    return [
      _strings.text('RESPONDA EMERGENCY REPORT'),
      '${_strings.text('Local ID')}: ${report.id}',
      '${_strings.text('Incident')}: ${_strings.text(draft.incidentType.label)}',
      'GPS: ${draft.coordinates}',
      '${_strings.text('Accuracy')}: $accuracy',
      if (landmark.isNotEmpty) '${_strings.text('Landmark')}: $landmark',
      '${_strings.text('Time')}: ${report.savedAt.toIso8601String()}',
      '${_strings.text('Details')}: ${draft.description}',
      '${_strings.text('More people need help')}: ${_yesNo(draft.morePeople)}',
      '${_strings.text('Additional assistance')}: ${_yesNo(draft.additionalAssistance)}',
      '${_strings.text('Still dangerous')}: ${_yesNo(draft.stillDangerous)}',
    ].join('\n');
  }

  String _yesNo(bool? value) => _strings.text(switch (value) {
    true => 'Yes',
    false => 'No',
    null => 'Not answered',
  });

  static String _encodeQueryParameters(Map<String, String> values) {
    return values.entries
        .map(
          (entry) =>
              '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}',
        )
        .join('&');
  }

  static Future<bool> _launchUri(Uri uri) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Try the platform default below.
    }

    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }
}
