import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.children,
    this.totalSteps = 5,
    super.key,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String subtitle;
  final List<Widget> children;

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
                  Row(
                    children: [
                      if (Navigator.of(context).canPop()) ...[
                        InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCF6F7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.brand),
                            ),
                            child: const Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.brand,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Image.asset(
                        'assets/images/responda_logo.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: LocalizedText(
                          'RESPONDA',
                          style: TextStyle(
                            color: AppColors.brand,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      LocalizedText(
                        context.tr(
                          '{step} of {total}',
                          values: {'step': step, 'total': totalSteps},
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: step / totalSteps,
                      minHeight: 7,
                      backgroundColor: AppColors.neutralSoft,
                      valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                    ),
                  ),
                  const SizedBox(height: 24),
                  LocalizedText(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  LocalizedText(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (var index = 0; index < children.length; index++) ...[
                    children[index],
                    if (index != children.length - 1)
                      const SizedBox(height: 14),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
