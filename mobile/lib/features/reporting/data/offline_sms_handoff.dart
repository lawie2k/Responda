import 'package:url_launcher/url_launcher.dart';

import '../../../core/network/responda_api_client.dart';
import 'offline_report_store.dart';

typedef SmsUriLauncher = Future<bool> Function(Uri uri);

class OfflineSmsHandoff {
  OfflineSmsHandoff({SmsUriLauncher? launcher})
    : _launcher = launcher ?? _launchUri;
  final SmsUriLauncher _launcher;
  Future<bool> openComposer(SavedOfflineReport report) =>
      _launcher(buildUri(report));
  Uri buildUri(SavedOfflineReport report) {
    final body = buildMessage(report);
    return Uri(
      scheme: 'sms',
      path: report.smsRecipient,
      query: 'body=${Uri.encodeComponent(body)}',
    );
  }

  String buildMessage(SavedOfflineReport report) {
    final body = report.signedMessage;
    if (body == null ||
        !body.startsWith('RSP1.') ||
        !RegExp(r'^\+639[0-9]{9}$').hasMatch(report.smsRecipient ?? '')) {
      throw const RespondaApiException(
        'This saved report has no signed SMS. Set up Offline SMS online, then create a new report.',
      );
    }
    return body;
  }

  static Future<bool> _launchUri(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
