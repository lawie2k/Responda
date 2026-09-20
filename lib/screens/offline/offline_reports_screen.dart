import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/reporting/data/offline_report_store.dart';

class OfflineReportsScreen extends StatefulWidget {
  const OfflineReportsScreen({
    this.store = const OfflineReportStore(),
    super.key,
  });

  final OfflineReportStore store;

  @override
  State<OfflineReportsScreen> createState() => _OfflineReportsScreenState();
}

class _OfflineReportsScreenState extends State<OfflineReportsScreen> {
  late Future<List<SavedOfflineReport>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = widget.store.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LocalizedText(
                            'My Reports',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 23,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          LocalizedText(
                            'Reports saved safely on this device',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const LocalizedText(
                        'OFFLINE',
                        style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _OfflineNotice(),
                const SizedBox(height: 12),
                Expanded(
                  child: FutureBuilder<List<SavedOfflineReport>>(
                    future: _reports,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brand,
                          ),
                        );
                      }
                      final reports = snapshot.data ?? const [];
                      if (reports.isEmpty) {
                        return const _EmptyReports();
                      }
                      return RefreshIndicator(
                        onRefresh: () async {
                          setState(() => _reports = widget.store.loadAll());
                          await _reports;
                        },
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: reports.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) =>
                              _SavedReportCard(report: reports[index]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineNotice extends StatelessWidget {
  const _OfflineNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, color: AppColors.warning, size: 21),
          SizedBox(width: 10),
          Expanded(
            child: LocalizedText(
              'No internet connection. New reports are saved on this phone and are not yet sent to MDRRMO.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                height: 17 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              color: AppColors.textSecondary,
              size: 48,
            ),
            SizedBox(height: 12),
            LocalizedText(
              'No saved offline reports',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedReportCard extends StatelessWidget {
  const _SavedReportCard({required this.report});

  final SavedOfflineReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121C1C1E),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: LocalizedText(
                  report.id,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const LocalizedText(
                  'NOT SENT',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LocalizedText(
            report.draft.incidentType.label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          LocalizedText(
            '${context.tr(report.draft.locationTitle)} · ${context.tr(report.draft.coordinates)}\n${context.tr('Waiting for connection')}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 17 / 12,
            ),
          ),
        ],
      ),
    );
  }
}
