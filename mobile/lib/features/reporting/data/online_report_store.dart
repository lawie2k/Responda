import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/report_draft.dart';

enum OnlineReportStatus {
  forVerification(
    label: 'FOR VERIFICATION',
    headline: 'Report received safely',
    description: 'MDRRMO is checking the submitted details.',
    stage: 2,
  ),
  needsReview(
    label: 'NEEDS REVIEW',
    headline: 'More verification is needed',
    description: 'MDRRMO could not verify the report yet and may contact you.',
    stage: 2,
  ),
  forDispatch(
    label: 'FOR DISPATCH',
    headline: 'Your report has been validated',
    description: 'MDRRMO is coordinating the response.',
    stage: 4,
  ),
  teamAssigned(
    label: 'TEAM ASSIGNED',
    headline: 'A response team is assigned',
    description: 'MDRRMO has assigned a team to this incident.',
    stage: 5,
  ),
  responding(
    label: 'RESPONDING',
    headline: 'The response team is responding',
    description: 'MDRRMO has confirmed that the team is responding.',
    stage: 6,
  ),
  resolved(
    label: 'RESOLVED',
    headline: 'The incident has been resolved',
    description: 'MDRRMO has marked the response as completed.',
    stage: 7,
  ),
  closed(
    label: 'CLOSED',
    headline: 'This report has been closed',
    description: 'MDRRMO has closed this report or its linked incident.',
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

  bool get isComplete => this == resolved || this == closed;
}

class SavedOnlineReport {
  const SavedOnlineReport({
    required this.id,
    required this.submittedAt,
    required this.draft,
    this.status = OnlineReportStatus.forVerification,
    this.updatedAt,
    this.milestones = const {},
  });

  final String id;
  final DateTime submittedAt;
  final ReportDraft draft;
  final OnlineReportStatus status;
  final DateTime? updatedAt;
  final Map<String, DateTime> milestones;

  Map<String, Object?> toJson() => {
    'id': id,
    'submittedAt': submittedAt.toIso8601String(),
    'draft': draft.toJson(),
    'status': status.name,
    'updatedAt': updatedAt?.toIso8601String(),
    'milestones': milestones.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    ),
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
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      milestones: (json['milestones'] as Map? ?? {}).map(
        (key, value) =>
            MapEntry(key as String, DateTime.parse(value as String)),
      ),
    );
  }
}

class OnlineReportStore {
  const OnlineReportStore();

  static const _storageKey = 'saved_online_reports_v1';

  Future<SavedOnlineReport> save(
    ReportDraft draft, {
    required String reportId,
    DateTime? submittedAt,
  }) async {
    final time = submittedAt ?? DateTime.now();
    final report = SavedOnlineReport(
      id: reportId,
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
}
