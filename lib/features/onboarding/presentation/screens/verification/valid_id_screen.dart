import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/presentation/models/identity_media_picker.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'face_capture_screen.dart';

class ValidIdScreen extends StatefulWidget {
  const ValidIdScreen({
    required this.phoneNumber,
    required this.mediaPicker,
    super.key,
  });

  final String phoneNumber;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<ValidIdScreen> createState() => _ValidIdScreenState();
}

class _ValidIdScreenState extends State<ValidIdScreen> {
  String? _idPath;
  bool _picking = false;

  Future<void> _pick(bool useCamera) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final path = widget.mediaPicker != null
          ? await widget.mediaPicker!(useCamera)
          : (await ImagePicker().pickImage(
              source: useCamera ? ImageSource.camera : ImageSource.gallery,
              imageQuality: 85,
              maxWidth: 2200,
              maxHeight: 2200,
            ))?.path;
      if (mounted && path != null) setState(() => _idPath = path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText('The ID image could not be opened.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 4,
      title: 'Upload a valid ID',
      subtitle:
          'Use a clear photo showing the complete ID and readable information.',
      children: [
        IdentityMediaPreview(
          path: _idPath,
          icon: Icons.badge_outlined,
          emptyTitle: 'No ID uploaded',
        ),
        const IdentityInfoCard(
          icon: Icons.verified_user_outlined,
          title: 'Accepted IDs',
          message: 'National ID, driver’s license, passport, voter’s ID, or another government-issued ID.',
        ),
        Row(
          children: [
            Expanded(
              child: RespondaButton(
                label: 'Take Photo',
                onPressed: _picking ? null : () => _pick(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: RespondaButton(
                label: 'Gallery',
                style: RespondaButtonStyle.secondary,
                onPressed: _picking ? null : () => _pick(false),
              ),
            ),
          ],
        ),
        RespondaButton(
          key: const Key('continue_identity_id_button'),
          label: 'Continue',
          onPressed: _idPath == null
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => FaceCaptureScreen(
                      phoneNumber: widget.phoneNumber,
                      idPath: _idPath!,
                      mediaPicker: widget.mediaPicker,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
