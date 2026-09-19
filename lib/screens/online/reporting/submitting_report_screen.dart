import 'dart:async';

import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';

import 'report_success_screen.dart';

class SubmittingReportScreen extends StatefulWidget {
  const SubmittingReportScreen({
    required this.draft,
    this.submitReport,
    super.key,
  });

  final ReportDraft draft;
  final Future<void> Function(ReportDraft draft)? submitReport;

  @override
  State<SubmittingReportScreen> createState() => _SubmittingReportScreenState();
}

class _SubmittingReportScreenState extends State<SubmittingReportScreen> {
  final _timers = <Timer>[];
  int _completedSteps = 1;

  @override
  void initState() {
    super.initState();
    _beginSubmission();
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const SizedBox(height: 30),
                    const Text(
                      'Sending your report to MDRRMO…',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 30 / 22,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please keep Responda open while submission completes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 19 / 14,
                      ),
                    ),
                    const SizedBox(height: 30),
                    _SubmissionStep(
                      label: 'Preparing report',
                      complete: _completedSteps >= 1,
                    ),
                    _SubmissionStep(
                      label: 'Checking location',
                      complete: _completedSteps >= 2,
                    ),
                    _SubmissionStep(
                      label: 'Sending securely',
                      complete: _completedSteps >= 3,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _beginSubmission() async {
    _timers.add(
      Timer(const Duration(milliseconds: 650), () {
        if (mounted) {
          setState(() => _completedSteps = 2);
        }
      }),
    );

    final submit = widget.submitReport;
    if (submit != null) {
      await submit(widget.draft);
    } else {
      await Future<void>.delayed(const Duration(milliseconds: 1300));
    }

    if (!mounted) {
      return;
    }
    setState(() => _completedSteps = 3);
    _timers.add(
      Timer(const Duration(milliseconds: 450), () {
        if (!mounted) {
          return;
        }
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ReportSuccessScreen(
              draft: widget.draft,
              submittedAt: DateTime.now(),
            ),
          ),
        );
      }),
    );
  }
}

class _SubmissionStep extends StatelessWidget {
  const _SubmissionStep({required this.label, required this.complete});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 42,
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: complete ? AppColors.success : AppColors.neutralSoft,
              shape: BoxShape.circle,
            ),
            child: complete
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: complete ? AppColors.textPrimary : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: complete ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
