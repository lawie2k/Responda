import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/report_step_scaffold.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';

import 'incident_location_screen.dart';

class IncidentTypeScreen extends StatefulWidget {
  const IncidentTypeScreen({
    this.initialType,
    this.flowMode = ReportFlowMode.online,
    this.onOpenSettings,
    super.key,
  });

  final IncidentType? initialType;
  final ReportFlowMode flowMode;
  final VoidCallback? onOpenSettings;

  @override
  State<IncidentTypeScreen> createState() => _IncidentTypeScreenState();
}

class _IncidentTypeScreenState extends State<IncidentTypeScreen> {
  late IncidentType? _selectedType = widget.initialType;

  static const _choices = <(IncidentType, String, String, double, double)>[
    (
      IncidentType.accident,
      'Road Accident',
      'assets/icons/report_accident.svg',
      26.273,
      21.018,
    ),
    (
      IncidentType.flood,
      'Flood',
      'assets/icons/report_flood.svg',
      27.045,
      21.636,
    ),
    (IncidentType.fire, 'Fire', 'assets/icons/report_fire.svg', 15.455, 20.606),
    (
      IncidentType.drowning,
      'Drowning',
      'assets/icons/report_drowning.svg',
      27.818,
      22.255,
    ),
    (
      IncidentType.other,
      'Other Disaster-Related Incident',
      'assets/icons/report_other.svg',
      18.545,
      18.545,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ReportStepScaffold(
      title: 'What happened?',
      step: 1,
      totalSteps: widget.flowMode.totalFormSteps,
      children: [
        const LocalizedText(
          'Choose the incident that best matches the situation.',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 19 / 14,
          ),
        ),
        for (final choice in _choices)
          _IncidentChoice(
            label: choice.$2,
            iconAsset: choice.$3,
            iconWidth: choice.$4,
            iconHeight: choice.$5,
            selected: choice.$1 == _selectedType,
            onTap: () => setState(() => _selectedType = choice.$1),
          ),
        RespondaButton(
          label: 'Continue',
          onPressed: _selectedType == null
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => IncidentLocationScreen(
                        draft: ReportDraft(incidentType: _selectedType!),
                        flowMode: widget.flowMode,
                        onOpenSettings: widget.onOpenSettings,
                      ),
                    ),
                  );
                },
        ),
      ],
    );
  }
}

class _IncidentChoice extends StatelessWidget {
  const _IncidentChoice({
    required this.label,
    required this.iconAsset,
    required this.iconWidth,
    required this.iconHeight,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String iconAsset;
  final double iconWidth;
  final double iconHeight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 58,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? AppColors.brandSoft : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFCF6F7),
                borderRadius: BorderRadius.circular(11),
              ),
              child: SvgPicture.asset(
                iconAsset,
                width: iconWidth,
                height: iconHeight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LocalizedText(
                label,
                style: TextStyle(
                  color: selected ? AppColors.brand : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 19 / 14,
                ),
              ),
            ),
            SvgPicture.asset(
              selected
                  ? 'assets/icons/radio_selected.svg'
                  : 'assets/icons/radio_unselected.svg',
              width: 20,
              height: 20,
            ),
          ],
        ),
      ),
    );
  }
}
