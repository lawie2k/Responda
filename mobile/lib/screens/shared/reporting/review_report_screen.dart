import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/report_step_scaffold.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';

import 'add_photo_screen.dart';
import 'incident_location_screen.dart';
import 'report_details_screen.dart';
import 'submitting_report_screen.dart';

class ReviewReportScreen extends StatefulWidget {
  const ReviewReportScreen({
    required this.draft,
    this.flowMode = ReportFlowMode.online,
    super.key,
  });

  final ReportDraft draft;
  final ReportFlowMode flowMode;

  @override
  State<ReviewReportScreen> createState() => _ReviewReportScreenState();
}

class _ReviewReportScreenState extends State<ReviewReportScreen> {
  late ReportDraft _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
  }

  @override
  Widget build(BuildContext context) {
    return ReportStepScaffold(
      title: 'Review Your Report',
      step: widget.flowMode.isOffline ? 4 : 5,
      totalSteps: widget.flowMode.totalFormSteps,
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
                LocalizedText(
                  _draft.incidentType.label,
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
                value:
                    '${context.tr(_draft.locationTitle)}\n${context.tr(_draft.coordinates)}',
                editKey: const Key('review_edit_location'),
                onEdit: _editLocation,
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'Description',
                value: _draft.description,
                editKey: const Key('review_edit_description'),
                onEdit: _editDetails,
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'More people',
                value: context.tr(_yesNo(_draft.morePeople)),
                editKey: const Key('review_edit_more_people'),
                onEdit: _editDetails,
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'Assistance',
                value: context.tr(_yesNo(_draft.additionalAssistance)),
                editKey: const Key('review_edit_assistance'),
                onEdit: _editDetails,
              ),
              const Divider(height: 18, color: AppColors.border),
              _SummaryRow(
                label: 'Still dangerous',
                value: context.tr(_yesNo(_draft.stillDangerous)),
                editKey: const Key('review_edit_danger'),
                onEdit: _editDetails,
              ),
              if (!widget.flowMode.isOffline) ...[
                const Divider(height: 18, color: AppColors.border),
                _SummaryRow(
                  label: 'Photo',
                  value: context.tr(
                    _draft.photoPath == null ? 'Not attached' : 'Attached',
                  ),
                  editKey: const Key('review_edit_photo'),
                  onEdit: _editPhoto,
                ),
              ],
            ],
          ),
        ),
        LocalizedText(
          widget.flowMode.isOffline
              ? 'This report will be saved on this phone. It has not reached MDRRMO yet.'
              : 'Please make sure the information is as accurate as possible.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            height: 17 / 12,
          ),
        ),
        if (widget.flowMode.isOffline) const _OfflineSmsHandoffCard(),
        RespondaButton(
          key: const Key('review_submit_button'),
          label: widget.flowMode.isOffline
              ? 'SAVE REPORT & OPEN SMS'
              : 'SUBMIT EMERGENCY REPORT',
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SubmittingReportScreen(
                  draft: _draft,
                  flowMode: widget.flowMode,
                ),
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

  Future<void> _editLocation() async {
    final updatedDraft = await Navigator.of(context).push<ReportDraft>(
      MaterialPageRoute<ReportDraft>(
        builder: (_) => IncidentLocationScreen(
          draft: _draft,
          flowMode: widget.flowMode,
          returnToReview: true,
        ),
      ),
    );
    _applyUpdate(updatedDraft);
  }

  Future<void> _editDetails() async {
    final updatedDraft = await Navigator.of(context).push<ReportDraft>(
      MaterialPageRoute<ReportDraft>(
        builder: (_) => ReportDetailsScreen(
          draft: _draft,
          flowMode: widget.flowMode,
          returnToReview: true,
        ),
      ),
    );
    _applyUpdate(updatedDraft);
  }

  Future<void> _editPhoto() async {
    final updatedDraft = await Navigator.of(context).push<ReportDraft>(
      MaterialPageRoute<ReportDraft>(
        builder: (_) => AddPhotoScreen(draft: _draft, returnToReview: true),
      ),
    );
    _applyUpdate(updatedDraft);
  }

  void _applyUpdate(ReportDraft? updatedDraft) {
    if (updatedDraft != null && mounted) {
      setState(() => _draft = updatedDraft);
    }
  }
}

class _OfflineSmsHandoffCard extends StatelessWidget {
  const _OfflineSmsHandoffCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sms_outlined, color: AppColors.brand, size: 22),
              SizedBox(width: 9),
              Expanded(
                child: LocalizedText(
                  'Offline SMS handoff',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 9),
          LocalizedText(
            'A copy will be saved on this phone, then Messages will open for 09476236516 with your report already filled in.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              height: 17 / 12,
            ),
          ),
          SizedBox(height: 8),
          LocalizedText(
            'You must review the message and tap Send in the SMS app.',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 17 / 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.editKey,
    required this.onEdit,
  });

  final String label;
  final String value;
  final Key editKey;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: LocalizedText(
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
        const SizedBox(width: 2),
        IconButton(
          key: editKey,
          tooltip: context.tr(
            'Edit {label}',
            values: {'label': context.tr(label)},
          ),
          onPressed: onEdit,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.edit_outlined,
            color: AppColors.brand,
            size: 18,
          ),
        ),
      ],
    );
  }
}
