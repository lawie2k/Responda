import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/report_step_scaffold.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';

import 'submitting_report_screen.dart';

class ReviewReportScreen extends StatelessWidget {
  const ReviewReportScreen({required this.draft, super.key});

  final ReportDraft draft;

  @override
  Widget build(BuildContext context) {
    return ReportStepScaffold(
      title: 'Review Your Report',
      step: 5,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  draft.incidentType.label,
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              _SummaryRow(
                label: 'Location',
                value: '${draft.locationTitle}\n${draft.coordinates}',
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(label: 'Description', value: draft.description),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'More people',
                value: _yesNo(draft.morePeople),
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'Assistance',
                value: _yesNo(draft.additionalAssistance),
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'Still dangerous',
                value: _yesNo(draft.stillDangerous),
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'Photo',
                value: draft.photoPath == null ? 'Not attached' : 'Attached',
              ),
            ],
          ),
        ),
        const Text(
          'Please make sure the information is as accurate as possible.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 17 / 12,
          ),
        ),
        RespondaButton(
          key: const Key('review_submit_button'),
          label: 'SUBMIT EMERGENCY REPORT',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SubmittingReportScreen(draft: draft),
              ),
            );
          },
        ),
      ],
    );
  }

  static String _yesNo(bool? value) => switch (value) {
    true => 'Yes',
    false => 'No',
    null => 'Not answered',
  };
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 17 / 12,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              height: 18 / 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.edit_outlined, color: AppColors.brand, size: 16),
      ],
    );
  }
}
