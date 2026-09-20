import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';
import 'package:responda/screens/shared/reporting/incident_location_screen.dart';
import 'package:responda/screens/shared/reporting/incident_type_screen.dart';

class OfflineSmsGatewayScreen extends StatelessWidget {
  const OfflineSmsGatewayScreen({this.initialType, super.key});

  final IncidentType? initialType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GatewayHeader(),
                  const SizedBox(height: 24),
                  const _SmsHero(),
                  const SizedBox(height: 16),
                  const LocalizedText(
                    'CHOOSE A BACKUP',
                    style: TextStyle(
                      color: Color(0xFF85858A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const _SmsOptionCard(),
                  const SizedBox(height: 12),
                  const _IncludedDetails(),
                  const SizedBox(height: 12),
                  RespondaButton(
                    key: const Key('continue_with_sms_button'),
                    label: 'Continue with SMS',
                    height: 52,
                    onPressed: () => _continue(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _continue(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => initialType == null
            ? const IncidentTypeScreen(flowMode: ReportFlowMode.offline)
            : IncidentLocationScreen(
                draft: ReportDraft(incidentType: initialType!),
                flowMode: ReportFlowMode.offline,
              ),
      ),
    );
  }
}

class _GatewayHeader extends StatelessWidget {
  const _GatewayHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Row(
        children: [
          InkWell(
            key: const Key('offline_gateway_back_button'),
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.brand, width: 1.2),
              ),
              child: const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.brand,
                size: 28,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: LocalizedText(
              'No Internet Connection',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmsHero extends StatelessWidget {
  const _SmsHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 226,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF7A1F2B),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                const Positioned(
                  left: 0,
                  top: 0,
                  width: 222,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        'SMS can still reach\nhelp',
                        maxLines: 2,
                        style: TextStyle(
                          color: AppColors.surface,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 28 / 22,
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: 205,
                        child: LocalizedText(
                          'Use the cellular network to hand off your report.',
                          maxLines: 3,
                          style: TextStyle(
                            color: Color(0xFFF7DDE1),
                            fontSize: 12,
                            height: 17 / 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: -5,
                  top: -35,
                  child: Image.asset(
                    'assets/images/no-internet.gif',
                    key: const Key('offline_gateway_sprite'),
                    width: 124,
                    height: 174,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B3541),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: _HeroStatus(
                    label: 'Internet',
                    color: Color(0xFFF25C54),
                  ),
                ),
                Expanded(
                  child: _HeroStatus(
                    label: 'SMS ready',
                    color: Color(0xFF7DE0A2),
                  ),
                ),
                Expanded(
                  child: _HeroStatus(
                    label: 'Save copy',
                    color: Color(0xFF7DE0A2),
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

class _HeroStatus extends StatelessWidget {
  const _HeroStatus({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: LocalizedText(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SmsOptionCard extends StatelessWidget {
  const _SmsOptionCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
      child: const Row(
        children: [
          _PhoneIcon(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Send via SMS',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                LocalizedText(
                  'Includes incident details, GPS coordinates, and timestamp.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    height: 17 / 12,
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

class _PhoneIcon extends StatelessWidget {
  const _PhoneIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.phone_outlined, color: AppColors.brand, size: 25),
    );
  }
}

class _IncludedDetails extends StatelessWidget {
  const _IncludedDetails();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEF),
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${context.tr('Included:')}   ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: context.tr('Incident  •  GPS  •  Time')),
          ],
        ),
        style: const TextStyle(
          color: AppColors.brand,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
