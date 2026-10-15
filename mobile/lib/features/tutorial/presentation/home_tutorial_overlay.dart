import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';

class HomeTutorialOverlay extends StatelessWidget {
  const HomeTutorialOverlay({
    required this.step,
    required this.targetKey,
    required this.coordinateSpaceKey,
    required this.onNext,
    required this.onSkip,
    super.key,
  });

  final int step;
  final GlobalKey targetKey;
  final GlobalKey coordinateSpaceKey;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  static const _content = <({String title, String message})>[
    (
      title: 'Report an emergency',
      message: 'Tap this button to create a complete emergency report with the incident, location, details, and photo.',
    ),
    (
      title: 'Use a quick incident type',
      message: 'Tap an incident shortcut when every second matters. RESPONDA will start the report with that type selected.',
    ),
    (
      title: 'Check your GPS location',
      message: 'This card shows your current coordinates and GPS accuracy before you create a report.',
    ),
    (
      title: 'Call MDRRMO',
      message: 'Use this button to open the phone dialer with the MDRRMO number. You will still press Call yourself.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final targetContext = targetKey.currentContext;
    final renderObject = targetContext?.findRenderObject();
    final coordinateContext = coordinateSpaceKey.currentContext;
    final coordinateRenderObject = coordinateContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        coordinateRenderObject is! RenderBox ||
        !coordinateRenderObject.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          (context as Element).markNeedsBuild();
        }
      });
      return const SizedBox.shrink();
    }

    final coordinateOrigin = coordinateRenderObject.localToGlobal(Offset.zero);
    final targetRect =
        (renderObject.localToGlobal(Offset.zero) - coordinateOrigin) &
        renderObject.size;
    final item = _content[step];

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
          final spotlight = step == 3
              ? Rect.fromCircle(
                  center: Offset(targetRect.center.dx, targetRect.top + 12),
                  radius: 39,
                )
              : targetRect.inflate(7);
          const spriteWidth = 104.0;
          const spriteHeight = 145.0;
          final safeTop = MediaQuery.paddingOf(context).top + 6;
          final roomOnLeft = spotlight.left >= spriteWidth + 10;
          final roomOnRight =
              screenSize.width - spotlight.right >= spriteWidth + 10;
          final pointLeft = !roomOnLeft && roomOnRight;
          final isGpsStep = step == 2;
          final spriteLeft = isGpsStep
              ? (spotlight.center.dx - spriteWidth * 0.72).clamp(
                  0.0,
                  screenSize.width - spriteWidth,
                )
              : roomOnLeft
              ? spotlight.left - spriteWidth - 6
              : roomOnRight
              ? spotlight.right + 6
              : 0.0;
          final spriteTop = isGpsStep
              ? (spotlight.bottom + 4).clamp(
                  safeTop,
                  screenSize.height - spriteHeight - 6,
                )
              : (spotlight.center.dy - 48).clamp(
                  safeTop,
                  screenSize.height - spriteHeight - 6,
                );
          final panelTop = step == 3
              ? (spotlight.top - 335).clamp(safeTop, screenSize.height - 200)
              : spotlight.center.dy < screenSize.height * 0.55
              ? (spotlight.bottom + 165).clamp(safeTop, screenSize.height - 195)
              : (spotlight.top - 240).clamp(safeTop, screenSize.height - 195);

          return Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: CustomPaint(
                      painter: _TutorialDimPainter(spotlight: spotlight),
                    ),
                  ),
                ),
                Positioned(
                  left: spriteLeft,
                  top: spriteTop,
                  width: spriteWidth,
                  height: spriteHeight,
                  child: Image.asset(
                    isGpsStep
                        ? 'assets/images/tutorial-point-up.gif'
                        : pointLeft
                        ? 'assets/images/tutorial-point-left.gif'
                        : 'assets/images/tutorial-point-right.gif',
                    key: const Key('home_tutorial_sprite'),
                    width: spriteWidth,
                    height: spriteHeight,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned(
                  left: 24,
                  right: 24,
                  top: panelTop,
                  child: Container(
                    key: const Key('home_tutorial_explanation_box'),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x40000000),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LocalizedText(
                          item.title,
                          style: const TextStyle(
                            color: AppColors.brand,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        LocalizedText(
                          item.message,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 16 / 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            TextButton(
                              key: const Key('skip_home_tutorial'),
                              onPressed: onSkip,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: const LocalizedText('Skip'),
                            ),
                            const Spacer(),
                            Text(
                              '${step + 1}/${_content.length}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 6),
                            FilledButton(
                              key: const Key('next_home_tutorial'),
                              onPressed: onNext,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                ),
                                minimumSize: const Size(0, 36),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                              child: LocalizedText(
                                step == _content.length - 1 ? 'Got it' : 'Next',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TutorialDimPainter extends CustomPainter {
  const _TutorialDimPainter({required this.spotlight});

  final Rect spotlight;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(spotlight, const Radius.circular(18)));
    final overlay = Path.combine(PathOperation.difference, screen, hole);
    canvas.drawPath(overlay, Paint()..color = const Color(0xC2616166));
    canvas.drawRRect(
      RRect.fromRectAndRadius(spotlight, const Radius.circular(18)),
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  @override
  bool shouldRepaint(_TutorialDimPainter oldDelegate) =>
      oldDelegate.spotlight != spotlight;
}
