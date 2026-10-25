import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/report_draft.dart';
import 'mobile_report_api.dart';
import '../../../core/network/responda_api_client.dart';

class SavedOfflineReport {
  const SavedOfflineReport({
    required this.id,
    required this.savedAt,
    required this.draft,
    this.signedMessage,
    this.smsRecipient,
  });

  final String id;
  final DateTime savedAt;
  final ReportDraft draft;
  final String? signedMessage;
  final String? smsRecipient;

  Map<String, Object?> toJson() => {
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'draft': draft.toJson(),
    'signedMessage': signedMessage,
    'smsRecipient': smsRecipient,
  };

  factory SavedOfflineReport.fromJson(Map<String, Object?> json) {
    return SavedOfflineReport(
      id: json['id'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      draft: ReportDraft.fromJson(
        Map<String, Object?>.from(json['draft'] as Map),
      ),
      signedMessage: json['signedMessage'] as String?,
      smsRecipient: json['smsRecipient'] as String?,
    );
  }
}

class OfflineReportStore {
  const OfflineReportStore();

  static const _storageKey = 'saved_offline_reports_v1';

  Future<SavedOfflineReport> save(
    ReportDraft draft, {
    String? signedMessage,
    String? smsRecipient,
    DateTime? createdAt,
  }) async {
    final savedAt = createdAt ?? DateTime.now();
    final clientId =
        draft.clientReportId ?? MobileReportApi.createClientReportId();
    final report = SavedOfflineReport(
      id: 'LOCAL-${clientId.replaceAll('-', '').substring(0, 8).toUpperCase()}',
      savedAt: savedAt,
      draft: draft.copyWith(clientReportId: clientId),
      signedMessage: signedMessage,
      smsRecipient: smsRecipient,
    );
    final reports = await loadAll();
    final existing = reports
        .where((item) => item.draft.clientReportId == clientId)
        .firstOrNull;
    if (existing?.signedMessage != null) {
      if (jsonEncode(existing!.draft.toJson()) !=
          jsonEncode(report.draft.toJson())) {
        throw const RespondaApiException(
          'This report already has a prepared SMS. Create a new report for changed details.',
        );
      }
      return existing;
    }
    await _write([
      report,
      ...reports.where((item) => item.draft.clientReportId != clientId),
    ]);
    return report;
  }

  Future<List<SavedOfflineReport>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_storageKey) ?? const [];
    final reports = <SavedOfflineReport>[];
    for (final value in encoded) {
      try {
        reports.add(
          SavedOfflineReport.fromJson(
            Map<String, Object?>.from(jsonDecode(value) as Map),
          ),
        );
      } catch (_) {
        // Ignore a damaged entry so other locally saved reports remain usable.
      }
    }
    return reports;
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  Future<void> _write(List<SavedOfflineReport> reports) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      reports.map((report) => jsonEncode(report.toJson())).toList(),
    );
  }
}
