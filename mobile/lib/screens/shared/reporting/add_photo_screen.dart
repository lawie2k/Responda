import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/report_step_scaffold.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';

import 'review_report_screen.dart';

typedef ReportPhotoPicker = Future<String?> Function(bool useCamera);

class AddPhotoScreen extends StatefulWidget {
  const AddPhotoScreen({
    required this.draft,
    this.pickPhoto,
    this.returnToReview = false,
    super.key,
  });

  final ReportDraft draft;
  final ReportPhotoPicker? pickPhoto;
  final bool returnToReview;

  @override
  State<AddPhotoScreen> createState() => _AddPhotoScreenState();
}

class _AddPhotoScreenState extends State<AddPhotoScreen> {
  String? _photoPath;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _photoPath = widget.draft.photoPath;
  }

  @override
  Widget build(BuildContext context) {
    return ReportStepScaffold(
      title: 'Add a Photo',
      step: 4,
      children: [
        const _SafetyCard(),
        _PhotoPreview(photoPath: _photoPath),
        Row(
          children: [
            Expanded(
              child: RespondaButton(
                label: 'Take Photo',
                onPressed: _isPicking ? null : () => _pickPhoto(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RespondaButton(
                label: 'Gallery',
                style: RespondaButtonStyle.secondary,
                onPressed: _isPicking ? null : () => _pickPhoto(false),
              ),
            ),
          ],
        ),
        RespondaButton(
          label: _photoPath == null ? 'Skip for now' : 'Continue',
          style: RespondaButtonStyle.ghost,
          onPressed: _isPicking ? null : _continue,
        ),
      ],
    );
  }

  Future<void> _pickPhoto(bool useCamera) async {
    setState(() => _isPicking = true);
    try {
      final picker = widget.pickPhoto;
      final path = picker != null
          ? await picker(useCamera)
          : (await ImagePicker().pickImage(
              source: useCamera ? ImageSource.camera : ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 2000,
              maxHeight: 2000,
            ))?.path;

      if (mounted && path != null) {
        setState(() => _photoPath = path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText(
              'The photo could not be opened. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  void _continue() {
    final updatedDraft = widget.draft.copyWith(photoPath: _photoPath);
    if (widget.returnToReview) {
      Navigator.of(context).pop(updatedDraft);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReviewReportScreen(draft: updatedDraft),
      ),
    );
  }
}

class _SafetyCard extends StatelessWidget {
  const _SafetyCard();

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
          LocalizedText(
            'Safety first',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          LocalizedText(
            'Optional — only take a photo if it is safe to do so.',
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

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.photoPath});

  final String? photoPath;

  @override
  Widget build(BuildContext context) {
    final path = photoPath;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(),
      child: Container(
        width: double.infinity,
        height: 230,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.neutralSoft,
          borderRadius: BorderRadius.circular(20),
        ),
        child: path == null
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_camera_outlined,
                    color: AppColors.brand,
                    size: 48,
                  ),
                  SizedBox(height: 10),
                  LocalizedText(
                    'No photo attached',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 6),
                  LocalizedText(
                    'Photos can help verify visible hazards.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(path), fit: BoxFit.cover),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const LocalizedText(
                        'Photo attached',
                        style: TextStyle(
                          color: AppColors.success,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)),
      );
    final paint = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 8), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
