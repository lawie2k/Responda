import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/report_step_scaffold.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';

import 'add_photo_screen.dart';
import 'review_report_screen.dart';

class ReportDetailsScreen extends StatefulWidget {
  const ReportDetailsScreen({
    required this.draft,
    this.flowMode = ReportFlowMode.online,
    this.returnToReview = false,
    super.key,
  });

  final ReportDraft draft;
  final ReportFlowMode flowMode;
  final bool returnToReview;

  @override
  State<ReportDetailsScreen> createState() => _ReportDetailsScreenState();
}

class _ReportDetailsScreenState extends State<ReportDetailsScreen> {
  final _descriptionController = TextEditingController();
  bool? _morePeople;
  bool? _additionalAssistance;
  bool? _stillDangerous;

  bool get _isComplete =>
      _descriptionController.text.trim().isNotEmpty &&
      _morePeople != null &&
      _additionalAssistance != null &&
      _stillDangerous != null;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.draft.description;
    _morePeople = widget.draft.morePeople;
    _additionalAssistance = widget.draft.additionalAssistance;
    _stillDangerous = widget.draft.stillDangerous;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ReportStepScaffold(
      title: 'Quick Details',
      step: 3,
      totalSteps: widget.flowMode.totalFormSteps,
      children: [
        _SelectedIncident(incidentType: widget.draft.incidentType),
        const Text(
          'Describe the situation',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 23 / 17,
          ),
        ),
        const _LanguageSupportTag(),
        const Text(
          'Incident description',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 18 / 13,
          ),
        ),
        TextField(
          controller: _descriptionController,
          onChanged: (_) => setState(() {}),
          minLines: 3,
          maxLines: 4,
          style: const TextStyle(fontSize: 14, height: 19 / 14),
          decoration: InputDecoration(
            hintText: 'Two motorcycles collided. One person is injured and one lane is blocked.',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
        const _HelpfulDetailsCard(),
        _QuestionChoice(
          question: 'Are there more people who need help?',
          value: _morePeople,
          onChanged: (value) => setState(() => _morePeople = value),
        ),
        _QuestionChoice(
          question: 'Does anyone need additional assistance?',
          value: _additionalAssistance,
          onChanged: (value) => setState(() => _additionalAssistance = value),
        ),
        _QuestionChoice(
          question: 'Is it still dangerous there?',
          value: _stillDangerous,
          onChanged: (value) => setState(() => _stillDangerous = value),
        ),
        RespondaButton(
          label: 'Continue',
          onPressed: _isComplete
              ? () {
                  final completedDraft = widget.draft.copyWith(
                    description: _descriptionController.text.trim(),
                    morePeople: _morePeople,
                    additionalAssistance: _additionalAssistance,
                    stillDangerous: _stillDangerous,
                  );
                  if (widget.returnToReview) {
                    Navigator.of(context).pop(completedDraft);
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => widget.flowMode.isOffline
                          ? ReviewReportScreen(
                              draft: completedDraft,
                              flowMode: widget.flowMode,
                            )
                          : AddPhotoScreen(draft: completedDraft),
                    ),
                  );
                }
              : null,
        ),
      ],
    );
  }
}

class _SelectedIncident extends StatelessWidget {
  const _SelectedIncident({required this.incidentType});

  final IncidentType incidentType;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: AppColors.brand,
            size: 19,
          ),
          const SizedBox(width: 8),
          const Text(
            'Incident type',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Text(
            incidentType.label,
            style: const TextStyle(
              color: AppColors.brand,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSupportTag extends StatelessWidget {
  const _LanguageSupportTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 28,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F0FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/icons/language_support_dot.svg',
            width: 7,
            height: 7,
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Bisaya · Tagalog · English supported',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 17 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpfulDetailsCard extends StatelessWidget {
  const _HelpfulDetailsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 5, 16, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFCF6F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Helpful details',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              height: 22 / 16,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Mention visible hazards, blocked roads, injuries, and anything changing quickly.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionChoice extends StatelessWidget {
  const _QuestionChoice({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final String question;
  final bool? value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 28 / 20,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: RespondaButton(
                label: 'Yes',
                height: 42,
                style: value == true
                    ? RespondaButtonStyle.primary
                    : RespondaButtonStyle.ghost,
                onPressed: () => onChanged(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RespondaButton(
                label: 'No',
                height: 42,
                style: value == false
                    ? RespondaButtonStyle.primary
                    : RespondaButtonStyle.ghost,
                onPressed: () => onChanged(false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
