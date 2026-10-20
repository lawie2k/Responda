import 'dart:math';

import '../domain/models/report_draft.dart';
import '../../onboarding/data/mobile_account_api.dart';

class MobileReportReceipt {
  const MobileReportReceipt({required this.reportId, required this.receivedAt});

  final String reportId;
  final DateTime receivedAt;

  factory MobileReportReceipt.fromJson(Map<String, dynamic> json) {
    final reportId = json['report_id'];
    final receivedAt = json['received_at'];
    if (reportId is! String || receivedAt is! String) {
      throw const FormatException('The report receipt is incomplete.');
    }
    return MobileReportReceipt(
      reportId: reportId,
      receivedAt: DateTime.parse(receivedAt),
    );
  }
}

class MobileReportApi {
  const MobileReportApi(this._accountApi);

  final MobileAccountApi _accountApi;

  Future<MobileReportReceipt> submit({
    required String token,
    required String clientReportId,
    required ReportDraft draft,
  }) async {
    final result = await _accountApi.submitReport(
      token: token,
      body: {
        'client_report_id': clientReportId,
        'incident_type_code': draft.incidentType.apiValue,
        'description': draft.description,
        'people_need_help': draft.morePeople ?? false,
        'additional_assistance': draft.additionalAssistance ?? false,
        'immediate_danger': draft.stillDangerous ?? false,
        'latitude': draft.latitude,
        'longitude': draft.longitude,
        'accuracy_meters': draft.locationAccuracy,
        'landmark': draft.landmark.trim().isEmpty
            ? null
            : draft.landmark.trim(),
        'location_captured_at': draft.locationCapturedAt
            ?.toUtc()
            .toIso8601String(),
      },
    );
    return MobileReportReceipt.fromJson(result);
  }

  static String createClientReportId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
