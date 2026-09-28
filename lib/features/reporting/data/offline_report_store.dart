import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/report_draft.dart';

class SavedOfflineReport {
  const SavedOfflineReport({
    required this.id,
    required this.savedAt,
    required this.draft,
  });

  final String id;
  final DateTime savedAt;
  final ReportDraft draft;

  Map<String, Object?> toJson() => {
    'id': id,
    'savedAt': savedAt.toIso8601String(),
    'draft': draft.toJson(),
  };

  factory SavedOfflineReport.fromJson(Map<String, Object?> json) {
    return SavedOfflineReport(
      id: json['id'] as String,
      savedAt: DateTime.parse(json['savedAt'] as String),
      draft: ReportDraft.fromJson(
        Map<String, Object?>.from(json['draft'] as Map),
      ),
    );
  }
}

class OfflineReportStore {
  const OfflineReportStore();

  static const _storageKey = 'saved_offline_reports_v1';

  Future<SavedOfflineReport> save(ReportDraft draft) async {
    final savedAt = DateTime.now();
    final report = SavedOfflineReport(
      id: _makeId(savedAt),
      savedAt: savedAt,
      draft: draft,
    );
    final reports = await loadAll();
    await _write([report, ...reports]);
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

  static String _makeId(DateTime time) {
    final sequence = time.millisecondsSinceEpoch.remainder(100000);
    return 'LOCAL-${sequence.toString().padLeft(5, '0')}';
  }
}
