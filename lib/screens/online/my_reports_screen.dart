import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/reporting/data/offline_report_store.dart';
import 'package:responda/features/reporting/data/online_report_store.dart';

import 'report_status_screen.dart';

enum ReportFilter { active, resolved, saved }

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({
    this.onlineStore = const OnlineReportStore(),
    this.offlineStore = const OfflineReportStore(),
    super.key,
  });

  final OnlineReportStore onlineStore;
  final OfflineReportStore offlineStore;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  ReportFilter _filter = ReportFilter.active;
  SavedOnlineReport? _selectedReport;
  late Future<_ReportsSnapshot> _reports = _loadReports();

  @override
  Widget build(BuildContext context) {
    final selectedReport = _selectedReport;
    return PopScope(
      canPop: _selectedReport == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedReport != null) {
          setState(() => _selectedReport = null);
        }
      },
      child: selectedReport != null
          ? ReportStatusContent(
              report: selectedReport,
              onBack: () => setState(() => _selectedReport = null),
            )
          : SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: FutureBuilder<_ReportsSnapshot>(
                    future: _reports,
                    builder: (context, snapshot) {
                      final reports = snapshot.data ?? const _ReportsSnapshot();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _ReportsHeader(activeCount: reports.online.length),
                            const SizedBox(height: 12),
                            _FilterTabs(
                              selected: _filter,
                              onSelected: (filter) =>
                                  setState(() => _filter = filter),
                            ),
                            const SizedBox(height: 12),
                            Expanded(
                              child: RefreshIndicator(
                                onRefresh: _refresh,
                                child: ListView(
                                  key: const Key('report_cards_scroll_view'),
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.only(bottom: 24),
                                  children:
                                      snapshot.connectionState !=
                                          ConnectionState.done
                                      ? const [_LoadingReports()]
                                      : _contentForFilter(reports),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
    );
  }

  Future<_ReportsSnapshot> _loadReports() async {
    final online = widget.onlineStore.loadAll();
    final offline = widget.offlineStore.loadAll();
    return _ReportsSnapshot(online: await online, offline: await offline);
  }

  Future<void> _refresh() async {
    final load = _loadReports();
    setState(() => _reports = load);
    await load;
  }

  List<Widget> _contentForFilter(_ReportsSnapshot reports) {
    return switch (_filter) {
      ReportFilter.active =>
        reports.online.isEmpty
            ? const [
                _EmptyReports(
                  title: 'No active reports',
                  message: 'Reports submitted online will appear here.',
                ),
              ]
            : [
                for (var index = 0; index < reports.online.length; index++) ...[
                  _ReportCard.online(
                    report: reports.online[index],
                    onTap: () => _openStatus(reports.online[index]),
                  ),
                  if (index != reports.online.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
      ReportFilter.resolved => const [
        _EmptyReports(
          title: 'No resolved reports',
          message: 'Completed reports will be moved here.',
        ),
      ],
      ReportFilter.saved =>
        reports.offline.isEmpty
            ? const [
                _SavedHeader(count: 0),
                SizedBox(height: 8),
                _EmptyReports(
                  title: 'No saved reports',
                  message: 'Reports saved while offline will appear here.',
                ),
              ]
            : [
                _SavedHeader(count: reports.offline.length),
                const SizedBox(height: 8),
                for (
                  var index = 0;
                  index < reports.offline.length;
                  index++
                ) ...[
                  _ReportCard.offline(
                    report: reports.offline[index],
                    onTap: () => _showOfflineReport(reports.offline[index]),
                  ),
                  if (index != reports.offline.length - 1)
                    const SizedBox(height: 12),
                ],
              ],
    };
  }

  void _openStatus(SavedOnlineReport report) {
    setState(() => _selectedReport = report);
  }

  void _showOfflineReport(SavedOfflineReport report) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.draft.incidentType.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${report.id}\n${report.draft.coordinates}\n${report.draft.description}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 19 / 13,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warningSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Text(
                  'Saved on this phone · Not yet sent',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsSnapshot {
  const _ReportsSnapshot({this.online = const [], this.offline = const []});

  final List<SavedOnlineReport> online;
  final List<SavedOfflineReport> offline;
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({required this.activeCount});

  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Reports',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  height: 29 / 23,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Track reports sent from this device',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 16 / 12,
                ),
              ),
            ],
          ),
        ),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brandSoft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            '$activeCount ACTIVE',
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onSelected});

  final ReportFilter selected;
  final ValueChanged<ReportFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final item in ReportFilter.values)
            Expanded(
              child: InkWell(
                onTap: () => onSelected(item),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: item == selected
                        ? AppColors.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: item == selected
                        ? const [
                            BoxShadow(
                              color: Color(0x141C1C1E),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    switch (item) {
                      ReportFilter.active => 'Active',
                      ReportFilter.resolved => 'Resolved',
                      ReportFilter.saved => 'Saved',
                    },
                    style: TextStyle(
                      color: item == selected
                          ? AppColors.brand
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: item == selected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.id,
    required this.title,
    required this.meta,
    required this.status,
    required this.statusColor,
    required this.statusBackground,
    required this.action,
    required this.onTap,
    this.offline = false,
  });

  factory _ReportCard.online({
    required SavedOnlineReport report,
    required VoidCallback onTap,
  }) {
    return _ReportCard(
      id: report.id,
      title: report.draft.incidentType.label,
      meta:
          '${report.draft.locationTitle}  •  ${_dateAndTime(report.submittedAt)}',
      status: report.status.label,
      statusColor: AppColors.warning,
      statusBackground: AppColors.warningSoft,
      action: 'View report status',
      onTap: onTap,
    );
  }

  factory _ReportCard.offline({
    required SavedOfflineReport report,
    required VoidCallback onTap,
  }) {
    return _ReportCard(
      id: report.id,
      title: report.draft.incidentType.label,
      meta: '${report.draft.locationTitle}  •  ${_dateAndTime(report.savedAt)}',
      status: 'NOT SENT',
      statusColor: AppColors.warning,
      statusBackground: AppColors.warningSoft,
      action: 'Open saved report',
      onTap: onTap,
      offline: true,
    );
  }

  final String id;
  final String title;
  final String meta;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final String action;
  final VoidCallback onTap;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                child: Text(
                  id,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _StatusBadge(
                label: status,
                color: statusColor,
                background: statusBackground,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            meta,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 17 / 12,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            key: ValueKey('report_action_$id'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: offline ? AppColors.warningSoft : AppColors.brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      action,
                      style: TextStyle(
                        color: offline ? AppColors.warning : AppColors.brand,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: offline ? AppColors.warning : AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedHeader extends StatelessWidget {
  const _SavedHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'SAVED OFFLINE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'report' : 'reports'}',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }
}

class _EmptyReports extends StatelessWidget {
  const _EmptyReports({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 20),
      child: Column(
        children: [
          const Icon(
            Icons.description_outlined,
            color: AppColors.textSecondary,
            size: 44,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
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

class _LoadingReports extends StatelessWidget {
  const _LoadingReports();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 72),
      child: Center(child: CircularProgressIndicator(color: AppColors.brand)),
    );
  }
}

String _dateAndTime(DateTime time) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final now = DateTime.now();
  final sameDay =
      now.year == time.year && now.month == time.month && now.day == time.day;
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  final date = sameDay
      ? 'Today'
      : '${time.day} ${months[time.month - 1]} ${time.year}';
  return '$date, $hour:$minute $period';
}
