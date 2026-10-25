import 'dart:async';

import 'package:flutter/material.dart';

import 'package:responda/core/network/responda_api_client.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/reporting/data/mobile_report_api.dart';
import 'package:responda/features/reporting/data/offline_report_store.dart';
import 'package:responda/features/reporting/data/online_report_store.dart';
import 'package:responda/features/reporting/presentation/sms_retry_button.dart';

import 'report_status_screen.dart';

enum ReportFilter { active, resolved, saved }

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({
    this.offlineStore = const OfflineReportStore(),
    this.isActive = true,
    super.key,
  });

  final OfflineReportStore offlineStore;
  final bool isActive;

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen>
    with WidgetsBindingObserver {
  ReportFilter _filter = ReportFilter.active;
  SavedOnlineReport? _selectedReport;
  AccountController? _account;
  MobileReportsPage? _reports;
  List<SavedOfflineReport> _offline = [];
  Timer? _timer;
  bool _busy = false;
  bool _reloadAfterRequest = false;
  bool _resumed = true;
  bool _started = false;
  bool _hadAccount = false;
  int _page = 1;
  int _activeCount = 0;
  int _requestVersion = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final account = AccountScope.maybeOf(context);
    if (!_started ||
        _account != account ||
        _hadAccount != (account?.hasAccount ?? false)) {
      _started = true;
      _account = account;
      _hadAccount = account?.hasAccount ?? false;
      _requestVersion++;
      _reports = null;
      _activeCount = 0;
      _selectedReport = null;
      _page = 1;
      _updatePolling();
      unawaited(_refresh());
    }
  }

  @override
  void didUpdateWidget(covariant MyReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updatePolling();
    if (widget.isActive && !oldWidget.isActive) unawaited(_refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    _updatePolling();
    if (_resumed) unawaited(_refresh());
  }

  void _updatePolling() {
    _timer?.cancel();
    if (widget.isActive &&
        _resumed &&
        _filter != ReportFilter.saved &&
        (_account?.hasAccount ?? false)) {
      _timer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_refresh()),
      );
    }
  }

  @override
  void dispose() {
    _requestVersion++;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted || !widget.isActive || !_resumed) return;
    if (_busy) {
      _reloadAfterRequest = true;
      return;
    }
    final version = _requestVersion;
    final account = _account;
    final selectedId = _selectedReport?.id;
    setState(() => _busy = true);
    try {
      final offline = await widget.offlineStore.loadAll();
      if (version != _requestVersion || !mounted) return;
      if (_filter == ReportFilter.saved) {
        setState(() {
          _offline = offline;
          _error = null;
        });
        return;
      }
      if (account == null) {
        throw const RespondaApiException(
          'Sign in to track your reports.',
          statusCode: 401,
        );
      }
      final selected = selectedId == null
          ? null
          : await account.fetchReport(selectedId);
      final reports = await account.fetchReports(
        completed: _filter == ReportFilter.resolved,
        page: _page,
      );
      if (!mounted || version != _requestVersion) return;
      if (reports.totalPages > 0 && _page > reports.totalPages) {
        _page = reports.totalPages;
        _requestVersion++;
        _reloadAfterRequest = true;
        return;
      }
      setState(() {
        _reports = reports;
        _activeCount = reports.activeCount;
        _offline = offline;
        _error = null;
        if (_selectedReport?.id == selectedId) _selectedReport = selected;
      });
    } catch (error) {
      if (!mounted || version != _requestVersion) return;
      setState(() {
        if (error is RespondaApiException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          _reports = null;
          _activeCount = 0;
          _selectedReport = null;
          _timer?.cancel();
          _error = 'Sign in to track your reports.';
        } else if (error is RespondaApiException &&
            error.statusCode == 404 &&
            selectedId != null) {
          _selectedReport = null;
          _error = 'This report is no longer available.';
        } else {
          _error = _reports == null
              ? 'Reports could not be loaded. Please try again.'
              : 'Could not refresh. Showing the last received update.';
        }
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        if (_reloadAfterRequest) {
          _reloadAfterRequest = false;
          unawaited(_refresh());
        }
      }
    }
  }

  void _selectFilter(ReportFilter filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _page = 1;
      _reports = null;
      _error = null;
      _requestVersion++;
    });
    _updatePolling();
    unawaited(_refresh());
  }

  void _backToReports() {
    setState(() {
      _selectedReport = null;
      _requestVersion++;
    });
    unawaited(_refresh());
  }

  @override
  Widget build(BuildContext context) {
    final selectedReport = _selectedReport;
    return PopScope(
      canPop: _selectedReport == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedReport != null) {
          _backToReports();
        }
      },
      child: selectedReport != null
          ? ReportStatusContent(
              report: selectedReport,
              onBack: _backToReports,
              onRefresh: _busy ? null : _refresh,
              refreshError: _error,
            )
          : SafeArea(
              bottom: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 390),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _ReportsHeader(activeCount: _activeCount),
                        const SizedBox(height: 12),
                        _FilterTabs(
                          selected: _filter,
                          onSelected: _selectFilter,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView(
                              key: const Key('report_cards_scroll_view'),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 24),
                              children: [
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Column(
                                      children: [
                                        LocalizedText(
                                          _error!,
                                          textAlign: TextAlign.center,
                                        ),
                                        TextButton(
                                          onPressed: _busy ? null : _refresh,
                                          child: const LocalizedText('Retry'),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_busy &&
                                    _reports == null &&
                                    _filter != ReportFilter.saved)
                                  const _LoadingReports()
                                else if (_filter == ReportFilter.saved ||
                                    _reports != null)
                                  ..._contentForFilter(),
                                if (_filter != ReportFilter.saved &&
                                    (_reports?.totalPages ?? 0) > 1)
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        tooltip: context.tr('Previous page'),
                                        onPressed: _page <= 1 || _busy
                                            ? null
                                            : () => _changePage(-1),
                                        icon: const Icon(Icons.chevron_left),
                                      ),
                                      Text('$_page / ${_reports!.totalPages}'),
                                      IconButton(
                                        tooltip: context.tr('Next page'),
                                        onPressed:
                                            _page >= _reports!.totalPages ||
                                                _busy
                                            ? null
                                            : () => _changePage(1),
                                        icon: const Icon(Icons.chevron_right),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  void _changePage(int delta) {
    setState(() {
      _page += delta;
      _reports = null;
      _requestVersion++;
    });
    unawaited(_refresh());
  }

  List<Widget> _contentForFilter() {
    final online = _reports?.items ?? const <SavedOnlineReport>[];
    return switch (_filter) {
      ReportFilter.active || ReportFilter.resolved =>
        online.isEmpty
            ? [
                _EmptyReports(
                  title: _filter == ReportFilter.active
                      ? 'No active reports'
                      : 'No completed reports',
                  message: _filter == ReportFilter.active
                      ? 'Reports submitted online will appear here.'
                      : 'Resolved and closed reports will appear here.',
                ),
              ]
            : [
                for (var index = 0; index < online.length; index++) ...[
                  _ReportCard.online(
                    context: context,
                    report: online[index],
                    onTap: () => _openStatus(online[index]),
                  ),
                  if (index != online.length - 1) const SizedBox(height: 12),
                ],
              ],
      ReportFilter.saved =>
        _offline.isEmpty
            ? const [
                _SavedHeader(count: 0),
                SizedBox(height: 8),
                _EmptyReports(
                  title: 'No saved reports',
                  message: 'Reports saved while offline will appear here.',
                ),
              ]
            : [
                _SavedHeader(count: _offline.length),
                const SizedBox(height: 8),
                for (var index = 0; index < _offline.length; index++) ...[
                  _ReportCard.offline(
                    context: context,
                    report: _offline[index],
                    onTap: () => _showOfflineReport(_offline[index]),
                  ),
                  if (index != _offline.length - 1) const SizedBox(height: 12),
                ],
              ],
    };
  }

  void _openStatus(SavedOnlineReport report) {
    setState(() {
      _selectedReport = report;
      _requestVersion++;
    });
    unawaited(_refresh());
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
              LocalizedText(
                report.draft.incidentType.label,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              LocalizedText(
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
                child: const LocalizedText(
                  'Saved on this phone · Delivery not confirmed',
                  style: TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SmsRetryButton(report: report),
            ],
          ),
        ),
      ),
    );
  }
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
              LocalizedText(
                'My Reports',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                  height: 29 / 23,
                ),
              ),
              SizedBox(height: 2),
              LocalizedText(
                'Track reports from your account',
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
          child: LocalizedText(
            context.tr('{count} ACTIVE', values: {'count': activeCount}),
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
                  child: LocalizedText(
                    switch (item) {
                      ReportFilter.active => 'Active',
                      ReportFilter.resolved => 'Completed',
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
    required BuildContext context,
    required SavedOnlineReport report,
    required VoidCallback onTap,
  }) {
    return _ReportCard(
      id: report.id,
      title: report.draft.incidentType.label,
      meta:
          '${context.tr(report.draft.locationTitle)}  •  ${_dateAndTime(context, report.submittedAt)}',
      status: report.status.label,
      statusColor: report.status == OnlineReportStatus.resolved
          ? AppColors.success
          : report.status == OnlineReportStatus.closed
          ? AppColors.textSecondary
          : AppColors.brand,
      statusBackground: report.status == OnlineReportStatus.resolved
          ? AppColors.successSoft
          : report.status == OnlineReportStatus.closed
          ? AppColors.neutralSoft
          : AppColors.brandSoft,
      action: 'View report status',
      onTap: onTap,
    );
  }

  factory _ReportCard.offline({
    required BuildContext context,
    required SavedOfflineReport report,
    required VoidCallback onTap,
  }) {
    return _ReportCard(
      id: report.id,
      title: report.draft.incidentType.label,
      meta:
          '${context.tr(report.draft.locationTitle)}  •  ${_dateAndTime(context, report.savedAt)}',
      status: 'NOT CONFIRMED',
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
                child: LocalizedText(
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
          LocalizedText(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 4),
          LocalizedText(
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
                    child: LocalizedText(
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
          LocalizedText(
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
          child: LocalizedText(
            'SAVED OFFLINE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        LocalizedText(
          context.tr(
            count == 1 ? '{count} report' : '{count} reports',
            values: {'count': count},
          ),
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
          LocalizedText(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          LocalizedText(
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

String _dateAndTime(BuildContext context, DateTime time) {
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
      ? context.tr('Today')
      : '${time.day} ${context.tr(months[time.month - 1])} ${time.year}';
  return '$date, $hour:$minute $period';
}
