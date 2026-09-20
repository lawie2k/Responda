import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/connectivity/connectivity_gate.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';

class ReportSuccessScreen extends StatelessWidget {
  const ReportSuccessScreen({
    required this.draft,
    required this.submittedAt,
    this.flowMode = ReportFlowMode.online,
    this.reportId,
    this.smsComposerOpened = false,
    super.key,
  });

  final ReportDraft draft;
  final DateTime submittedAt;
  final ReportFlowMode flowMode;
  final String? reportId;
  final bool smsComposerOpened;

  @override
  Widget build(BuildContext context) {
    final visibleReportId = reportId ?? _reportId(submittedAt);

    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 34),
                  Image.asset(
                    'assets/images/report_success.gif',
                    height: 190,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                  const SizedBox(height: 18),
                  LocalizedText(
                    flowMode.isOffline ? 'REPORT SAVED' : 'REPORT SENT',
                    style: TextStyle(
                      color: flowMode.isOffline
                          ? AppColors.warning
                          : AppColors.success,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedText(
                    flowMode.isOffline
                        ? smsComposerOpened
                              ? 'A copy is saved on this phone and your SMS draft was prepared for MDRRMO.'
                              : 'Your report is saved, but the phone SMS app could not be opened.'
                        : 'Your report has been sent to MDRRMO Pantukan for verification.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                      height: 21 / 15,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ReportCard(
                    title: visibleReportId,
                    body:
                        '${context.tr(draft.incidentType.label)} · ${context.tr(draft.locationTitle)}\n'
                        '${_dateAndTime(context, submittedAt)}',
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: flowMode.isOffline
                          ? AppColors.warningSoft
                          : AppColors.brandSoft,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LocalizedText(
                          'Important',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LocalizedText(
                          flowMode.isOffline
                              ? smsComposerOpened
                                    ? 'The app cannot confirm that an SMS was sent. Review the prepared message and tap Send in Messages.'
                                    : 'Your report is still safe on this device. Open it from My Reports and try the SMS handoff again.'
                              : 'Report received does not mean a rescue team has already been dispatched.',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 18 / 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  RespondaButton(
                    label: flowMode.isOffline
                        ? 'View Saved Report'
                        : 'View Report Status',
                    onPressed: () =>
                        _openShell(context, RespondaNavItem.reports),
                  ),
                  const SizedBox(height: 14),
                  RespondaButton(
                    label: 'Return Home',
                    style: RespondaButtonStyle.secondary,
                    onPressed: () => _openShell(context, RespondaNavItem.home),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void _openShell(BuildContext context, RespondaNavItem item) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => ConnectivityGate(initialItem: item),
      ),
      (_) => false,
    );
  }

  static String _reportId(DateTime time) {
    final sequence = time.millisecondsSinceEpoch.remainder(100000);
    return 'RSP-${time.year}-${sequence.toString().padLeft(5, '0')}';
  }

  static String _dateAndTime(BuildContext context, DateTime time) {
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
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '${time.day} ${context.tr(months[time.month - 1])} ${time.year} · '
        '$hour:$minute $period';
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LocalizedText(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}
