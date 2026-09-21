import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/models/identity_media_picker.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'verification_submitted_screen.dart';

class FaceCaptureScreen extends StatefulWidget {
  const FaceCaptureScreen({
    required this.phoneNumber,
    required this.idPath,
    required this.mediaPicker,
    super.key,
  });

  final String phoneNumber;
  final String idPath;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen>
    with WidgetsBindingObserver {
  String? _facePath;
  CameraController? _cameraController;
  String? _cameraError;
  bool _initializingCamera = false;
  bool _capturing = false;
  bool _submitting = false;

  bool get _usesLiveCamera => widget.mediaPicker == null;
  bool get _cameraReady =>
      !_usesLiveCamera || (_cameraController?.value.isInitialized ?? false);

  @override
  void initState() {
    super.initState();
    if (_usesLiveCamera) {
      WidgetsBinding.instance.addObserver(this);
      _initializeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_usesLiveCamera) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializingCamera) return;
    _initializingCamera = true;
    if (mounted) setState(() => _cameraError = null);
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
          'NoCameraAvailable',
          'No camera is available on this device.',
        );
      }
      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      final previousController = _cameraController;
      setState(() => _cameraController = controller);
      await previousController?.dispose();
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _cameraError = error.code == 'CameraAccessDenied'
              ? 'Camera permission is needed to take your face photo.'
              : 'The front camera is not available.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = 'The front camera is not available.');
      }
    } finally {
      _initializingCamera = false;
    }
  }

  @override
  void dispose() {
    if (_usesLiveCamera) WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing) return;
    setState(() => _capturing = true);
    try {
      final path = widget.mediaPicker != null
          ? await widget.mediaPicker!(true)
          : (await _cameraController!.takePicture()).path;
      if (mounted && path != null) setState(() => _facePath = path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText('The face photo could not be captured.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _submit() async {
    if (_facePath == null || _submitting) return;
    final controller = AccountScope.maybeOf(context);
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Account storage is not available.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    await controller.submitIdentity(phoneNumber: widget.phoneNumber);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            VerificationSubmittedScreen(phoneNumber: widget.phoneNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 5,
      title: 'Take a face photo',
      subtitle: 'Face the camera directly in a well-lit place. Remove masks, hats, and sunglasses.',
      children: [
        Center(
          child: _FaceCameraPreview(
            path: _facePath,
            controller: _cameraController,
            cameraError: _cameraError,
            usesLiveCamera: _usesLiveCamera,
          ),
        ),
        const IdentityInfoCard(
          icon: Icons.lock_outline_rounded,
          title: 'Used for identity review',
          message: 'Your photo will be compared with your valid ID by the authorized verification team.',
        ),
        RespondaButton(
          key: const Key('capture_identity_face_button'),
          label: _capturing ? 'Capturing…' : 'Capture Photo',
          onPressed: !_capturing && _cameraReady ? _capture : null,
        ),
        RespondaButton(
          key: const Key('submit_identity_button'),
          label: _submitting ? 'Submitting…' : 'Submit for Verification',
          onPressed: _facePath != null && !_submitting ? _submit : null,
        ),
      ],
    );
  }
}

class _FaceCameraPreview extends StatelessWidget {
  const _FaceCameraPreview({
    required this.path,
    required this.controller,
    required this.cameraError,
    required this.usesLiveCamera,
  });

  final String? path;
  final CameraController? controller;
  final String? cameraError;
  final bool usesLiveCamera;

  @override
  Widget build(BuildContext context) {
    final camera = controller;
    final previewSize = camera?.value.previewSize;
    final Widget content;
    if (path != null) {
      content = Image.file(File(path!), fit: BoxFit.cover);
    } else if (usesLiveCamera &&
        camera != null &&
        camera.value.isInitialized &&
        previewSize != null) {
      content = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: Transform.flip(flipX: true, child: CameraPreview(camera)),
        ),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            cameraError == null
                ? Icons.camera_front_rounded
                : Icons.no_photography_outlined,
            color: AppColors.brand,
            size: 42,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: LocalizedText(
              cameraError ??
                  (usesLiveCamera
                      ? 'Preparing camera…'
                      : 'Position your face here'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      key: const Key('identity_face_camera_preview'),
      width: 300,
      height: 300,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: AppColors.neutralSoft,
        shape: BoxShape.circle,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          content,
          if (path == null &&
              usesLiveCamera &&
              camera?.value.isInitialized == true)
            Align(
              alignment: const Alignment(0, 0.72),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: LocalizedText(
                    'Position your face here',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
