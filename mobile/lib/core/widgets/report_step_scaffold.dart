import 'package:responda/core/widgets/responda_glass.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

class ReportStepScaffold extends StatelessWidget {
  const ReportStepScaffold({
    required this.title,
    required this.step,
    required this.children,
    this.totalSteps = 5,
    this.onBack,
    super.key,
  });

  final String title;
  final int step;
  final int totalSteps;
  final List<Widget> children;
  final VoidCallback? onBack;

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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StepHeader(
                    title: title,
                    step: step,
                    totalSteps: totalSteps,
                    onBack: onBack ?? () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 24),
                  ..._withSpacing(children),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> values) {
    return [
      for (var index = 0; index < values.length; index++) ...[
        values[index],
        if (index != values.length - 1) const SizedBox(height: 14),
      ],
    ];
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });

  final String title;
  final int step;
  final int totalSteps;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          // Reserve space for native glass effects outside the button bounds.
          height: RespondaGlass.enabled(context) ? 64 : 44,
          child: Row(
            children: [
              RespondaIosBackButton(
                onPressed: onBack,
                fallback: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFCF6F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.brand),
                    ),
                    child: Transform.rotate(
                      angle: math.pi,
                      child: SvgPicture.asset(
                        'assets/icons/chevron.svg',
                        width: 18,
                        height: 18,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Spacer(),
              LocalizedText(
                context.tr(
                  '{step} of {total}',
                  values: {'step': step, 'total': totalSteps},
                ),
                style: const TextStyle(
                  color: AppColors.brand,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: RespondaGlass.enabled(context) ? 24 : 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: step / totalSteps,
            minHeight: 4,
            backgroundColor: const Color(0xFFF2F2F4),
            valueColor: const AlwaysStoppedAnimation(AppColors.brand),
          ),
        ),
        const SizedBox(height: 24),
        LocalizedText(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 28,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
