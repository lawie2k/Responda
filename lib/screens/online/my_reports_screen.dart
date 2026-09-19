import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';

enum ReportFilter { active, resolved, saved }

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  ReportFilter _filter = ReportFilter.active;

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
                _ReportsHeader(
                  activeCount: _filter == ReportFilter.active ? 2 : 0,
                ),
                const SizedBox(height: 12),
                _FilterTabs(
                  selected: _filter,
                  onSelected: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    key: const Key('report_cards_scroll_view'),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: _contentForFilter(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _contentForFilter() {
    return switch (_filter) {
      ReportFilter.active => const [
        _ReportCard(
          id: 'RSP-2026-00872',
          title: 'Road Accident',
          meta: 'Kingking Highway  •  Today, 9:41 AM',
          status: 'FOR VERIFICATION',
          statusColor: AppColors.warning,
          statusBackground: AppColors.warningSoft,
          action: 'View report status',
        ),
        SizedBox(height: 12),
        _ReportCard(
          id: 'RSP-2026-00791',
          title: 'Flood',
          meta: 'Barangay Magnaga  •  29 Aug, 5:20 PM',
          status: 'TEAM DISPATCHED',
          statusColor: AppColors.success,
          statusBackground: AppColors.successSoft,
          action: 'View response progress',
        ),
      ],
      ReportFilter.resolved => const [
        _ReportCard(
          id: 'RSP-2026-00643',
          title: 'Road Obstruction',
          meta: 'Poblacion  •  26 Aug, 3:15 PM',
          status: 'RESOLVED',
          statusColor: AppColors.success,
          statusBackground: AppColors.successSoft,
          action: 'View report summary',
        ),
      ],
      ReportFilter.saved => const [
        _SavedHeader(),
        SizedBox(height: 8),
        _ReportCard(
          id: 'LOCAL-0041',
          title: 'Road Accident',
          meta: 'Kingking  •  Waiting for connection',
          status: 'NOT SENT',
          statusColor: AppColors.warning,
          statusBackground: AppColors.warningSoft,
          action: 'Open saved report',
          offline: true,
        ),
      ],
    };
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
                  fontSize: 10,
                  height: 14 / 10,
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
              fontSize: 10,
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
    this.offline = false,
  });

  final String id;
  final String title;
  final String meta;
  final String status;
  final Color statusColor;
  final Color statusBackground;
  final String action;
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
                    fontSize: 10,
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
              fontSize: 10,
              height: 15 / 10,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {},
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
  const _SavedHeader();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: Text(
            'SAVED OFFLINE',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          '1 report',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}
