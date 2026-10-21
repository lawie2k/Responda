import 'dart:math';

import '../domain/models/report_draft.dart';
import '../domain/models/incident_type.dart';
import 'online_report_store.dart';
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

  Future<MobileReportsPage> list({
    required String token,
    bool completed = false,
    int page = 1,
  }) async {
    final result = await _accountApi.readReports(
      token: token,
      completed: completed,
      page: page,
    );
    return MobileReportsPage(
      items: (result['items'] as List)
          .map((item) => trackingReport(Map<String, dynamic>.from(item as Map)))
          .toList(),
      total: result['total'] as int,
      page: result['page'] as int,
      totalPages: result['total_pages'] as int,
      activeCount: result['active_count'] as int,
    );
  }

  Future<SavedOnlineReport> tracking({
    required String token,
    required String reportId,
  }) async => trackingReport(
    await _accountApi.readReports(token: token, reportId: reportId),
  );

  static SavedOnlineReport trackingReport(Map<String, dynamic> json) {
    final status = switch (json['tracking_status']) {
      'for_verification' => OnlineReportStatus.forVerification,
      'needs_review' => OnlineReportStatus.needsReview,
      'for_dispatch' => OnlineReportStatus.forDispatch,
      'team_assigned' => OnlineReportStatus.teamAssigned,
      'responding' => OnlineReportStatus.responding,
      'resolved' => OnlineReportStatus.resolved,
      'closed' => OnlineReportStatus.closed,
      _ => throw const FormatException('Unknown report status.'),
    };
    return SavedOnlineReport(
      id: json['report_id'] as String,
      submittedAt: DateTime.parse(json['received_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      status: status,
      milestones: (json['milestones'] as Map).map(
        (key, value) =>
            MapEntry(key as String, DateTime.parse(value as String).toLocal()),
      ),
      draft: ReportDraft(
        incidentType: IncidentType.values.firstWhere(
          (type) => type.apiValue == json['incident_type_code'],
          orElse: () => IncidentType.other,
        ),
        description: json['description'] as String,
        landmark: json['landmark'] as String? ?? '',
      ),
    );
  }

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

class MobileReportsPage {
  const MobileReportsPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.totalPages = 0,
    this.activeCount = 0,
  });

  final List<SavedOnlineReport> items;
  final int total;
  final int page;
  final int totalPages;
  final int activeCount;
}
