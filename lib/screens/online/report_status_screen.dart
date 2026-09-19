import 'package:flutter/material.dart';

import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/features/reporting/data/online_report_store.dart';

class ReportStatusScreen extends StatelessWidget {
  const ReportStatusScreen({required this.report, super.key});

  final SavedOnlineReport report;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatusHeader(onBack: () => Navigator.of(context).pop()),
                  const SizedBox(height: 24),
                  _StatusHero(report: report),
                  const SizedBox(height: 12),
                  _ReportJourney(report: report),
                  const SizedBox(height: 12),
                  const _ContactCard(),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Material(
        color: AppColors.surface,
        child: SafeArea(
          top: false,
          child: RespondaBottomNavigation(
            activeItem: RespondaNavItem.reports,
            onSelected: (item) => _openSection(context, item),
          ),
        ),
      ),
    );
  }

  static void _openSection(BuildContext context, RespondaNavItem item) {
    if (item == RespondaNavItem.reports) {
      Navigator.of(context).pop();
      return;
    }
    final route = switch (item) {
      RespondaNavItem.home => AppRoutes.home,
      RespondaNavItem.reports => AppRoutes.reports,
      RespondaNavItem.information => AppRoutes.emergencyInfo,
      RespondaNavItem.settings => AppRoutes.settings,
    };
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          InkWell(
            key: const Key('report_status_back_button'),
            onTap: onBack,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.brand),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.brand,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Report Status',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.report});

  final SavedOnlineReport report;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7A1F2B),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            report.status.label,
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  report.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFFF6DDE1),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.status.headline,
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            report.status.description,
            style: const TextStyle(color: Color(0xFFF6DDE1), fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF873440),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Text(
                  '${report.status.stage} OF 7 STAGES',
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated ${_clockTime(report.submittedAt.add(const Duration(minutes: 2)))}',
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportJourney extends StatelessWidget {
  const _ReportJourney({required this.report});

  final SavedOnlineReport report;

  @override
  Widget build(BuildContext context) {
    final verificationTime = report.submittedAt.add(const Duration(minutes: 2));
    final stages = [
      ('Report received', _clockTime(report.submittedAt), _StageState.complete),
      ('For verification', _clockTime(verificationTime), _StageState.current),
      ('Validated', 'Pending', _StageState.pending),
      ('For dispatch', 'Pending', _StageState.pending),
      ('Team dispatched', 'Pending', _StageState.pending),
      ('On site', 'Pending', _StageState.pending),
      ('Resolved', 'Pending', _StageState.pending),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x101C1C1E),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REPORT JOURNEY',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < stages.length; index++)
            _JourneyStage(
              title: stages[index].$1,
              subtitle: stages[index].$2,
              state: stages[index].$3,
              showNow: index == 1,
              showLine: index != stages.length - 1,
            ),
        ],
      ),
    );
  }
}

enum _StageState { complete, current, pending }

class _JourneyStage extends StatelessWidget {
  const _JourneyStage({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.showNow,
    required this.showLine,
  });

  final String title;
  final String subtitle;
  final _StageState state;
  final bool showNow;
  final bool showLine;

  @override
  Widget build(BuildContext context) {
    final complete = state == _StageState.complete;
    final current = state == _StageState.current;
    return SizedBox(
      height: 43,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: complete
                        ? AppColors.successSoft
                        : current
                        ? AppColors.brandSoft
                        : AppColors.neutralSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    complete ? Icons.check_rounded : Icons.circle_outlined,
                    size: complete ? 14 : 9,
                    color: complete
                        ? AppColors.success
                        : current
                        ? AppColors.brand
                        : AppColors.textSecondary,
                  ),
                ),
                if (showLine)
                  Expanded(child: Container(width: 1, color: AppColors.border)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: state == _StageState.pending
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: current ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (showNow)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.brandSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: AppColors.brand, size: 7),
                  SizedBox(width: 5),
                  Text(
                    'NOW',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'MDRRMO may call to confirm the incident, location, or assistance needed.',
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.infoSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surface,
              child: Icon(
                Icons.phone_outlined,
                color: AppColors.info,
                size: 20,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MDRRMO may contact you',
                    style: TextStyle(
                      color: AppColors.info,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Tap to see what to expect during verification.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.info, size: 21),
          ],
        ),
      ),
    );
  }
}

String _clockTime(DateTime time) {
  final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.hour < 12 ? 'AM' : 'PM';
  return '$hour:$minute $period';
}
