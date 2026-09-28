import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/report_draft.dart';

enum OnlineReportStatus {
  forVerification(
    label: 'FOR VERIFICATION',
    headline: 'Report received safely',
    description: 'MDRRMO is checking the submitted details.',
    stage: 2,
  );

  const OnlineReportStatus({
    required this.label,
    required this.headline,
    required this.description,
    required this.stage,
  });

  final String label;
  final String headline;
  final String description;
  final int stage;
}

class SavedOnlineReport {
  const SavedOnlineReport({
    required this.id,
    required this.submittedAt,
    required this.draft,
    this.status = OnlineReportStatus.forVerification,
  });

  final String id;
  final DateTime submittedAt;
  final ReportDraft draft;
  final OnlineReportStatus status;

  Map<String, Object?> toJson() => {
    'id': id,
    'submittedAt': submittedAt.toIso8601String(),
    'draft': draft.toJson(),
    'status': status.name,
  };

  factory SavedOnlineReport.fromJson(Map<String, Object?> json) {
    final statusName = json['status'] as String?;
    return SavedOnlineReport(
      id: json['id'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      draft: ReportDraft.fromJson(
        Map<String, Object?>.from(json['draft'] as Map),
      ),
      status: OnlineReportStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => OnlineReportStatus.forVerification,
      ),
    );
  }
}

class OnlineReportStore {
  const OnlineReportStore();

  static const _storageKey = 'saved_online_reports_v1';

  Future<SavedOnlineReport> save(
    ReportDraft draft, {
    DateTime? submittedAt,
  }) async {
    final time = submittedAt ?? DateTime.now();
    final report = SavedOnlineReport(
      id: _makeId(time),
      submittedAt: time,
      draft: draft,
    );
    final reports = await loadAll();
    await _write([report, ...reports]);
    return report;
  }

  Future<List<SavedOnlineReport>> loadAll() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getStringList(_storageKey) ?? const [];
    final reports = <SavedOnlineReport>[];
    for (final value in encoded) {
      try {
        reports.add(
          SavedOnlineReport.fromJson(
            Map<String, Object?>.from(jsonDecode(value) as Map),
          ),
        );
      } catch (_) {
        // Keep the usable reports if one stored entry is damaged.
      }
    }
    return reports;
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  Future<void> _write(List<SavedOnlineReport> reports) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      reports.map((report) => jsonEncode(report.toJson())).toList(),
    );
  }

  static String _makeId(DateTime time) {
    final sequence = time.millisecondsSinceEpoch.remainder(100000);
    return 'RSP-${time.year}-${sequence.toString().padLeft(5, '0')}';
  }
}
