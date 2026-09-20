import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';

import '../../data/identity_otp_service.dart';
import '../account_scope.dart';

typedef IdentityMediaPicker = Future<String?> Function(bool useCamera);

class IdentityVerificationScreen extends StatefulWidget {
  const IdentityVerificationScreen({
    this.otpService = const PrototypeIdentityOtpService(),
    this.mediaPicker,
    super.key,
  });

  final IdentityOtpService otpService;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<IdentityVerificationScreen> createState() =>
      _IdentityVerificationScreenState();
}

class _IdentityVerificationScreenState
    extends State<IdentityVerificationScreen> {
  final _phoneController = TextEditingController();
  bool _consented = false;
  bool _sending = false;

  bool get _validPhone =>
      _phoneController.text.length == 10 &&
      _phoneController.text.startsWith('9');

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (_sending) {
      return;
    }
    if (!_validPhone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Enter a 10-digit mobile number starting with 9.',
          ),
        ),
      );
      return;
    }
    if (!_consented) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'Please accept the identity verification consent.',
          ),
        ),
      );
      return;
    }
    setState(() => _sending = true);
    final phoneNumber = '+63${_phoneController.text}';
    try {
      await widget.otpService.sendCode(phoneNumber);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => _OtpVerificationScreen(
            phoneNumber: phoneNumber,
            otpService: widget.otpService,
            mediaPicker: widget.mediaPicker,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText('The verification code could not be sent.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _IdentityScaffold(
      step: 1,
      title: 'Verify your identity',
      subtitle:
          'Create or recover your RESPONDA account using your mobile number.',
      children: [
        const _InfoCard(
          icon: Icons.phone_iphone_rounded,
          title: 'One account per phone number',
          message: 'Already registered? Use the same phone number and OTP to recover your verified account.',
        ),
        const LocalizedText(
          'Mobile number',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextField(
          key: const Key('identity_phone_field'),
          controller: _phoneController,
          autofocus: false,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(
            hintText: '9XX XXX XXXX',
            prefixText: '+63  ',
          ),
        ),
        InkWell(
          onTap: () => setState(() => _consented = !_consented),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  key: const Key('identity_consent_checkbox'),
                  value: _consented,
                  activeColor: AppColors.brand,
                  onChanged: (value) =>
                      setState(() => _consented = value ?? false),
                ),
                const SizedBox(width: 4),
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LocalizedText(
                      'I consent to using my phone number, valid ID, and face photo for identity verification.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 17 / 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        RespondaButton(
          key: const Key('send_identity_otp_button'),
          label: _sending ? 'Sending…' : 'Send OTP',
          onPressed: _sending ? null : _sendCode,
        ),
        const _PrototypeNotice(),
      ],
    );
  }
}

class _OtpVerificationScreen extends StatefulWidget {
  const _OtpVerificationScreen({
    required this.phoneNumber,
    required this.otpService,
    required this.mediaPicker,
  });

  final String phoneNumber;
  final IdentityOtpService otpService;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<_OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<_OtpVerificationScreen> {
  final _codeController = TextEditingController();
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.length != 6 || _verifying) {
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    final valid = await widget.otpService.verifyCode(
      widget.phoneNumber,
      _codeController.text,
    );
    if (!mounted) {
      return;
    }
    setState(() => _verifying = false);
    if (!valid) {
      setState(() => _error = 'That code is incorrect. Please try again.');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ValidIdScreen(
          phoneNumber: widget.phoneNumber,
          mediaPicker: widget.mediaPicker,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _IdentityScaffold(
      step: 2,
      title: 'Enter your OTP',
      subtitle: context.tr(
        'Enter the 6-digit code sent to {phone}.',
        values: {'phone': widget.phoneNumber},
      ),
      children: [
        TextField(
          key: const Key('identity_otp_field'),
          controller: _codeController,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          onChanged: (_) => setState(() => _error = null),
          decoration: _inputDecoration(
            hintText: '000000',
            errorText: _error == null ? null : context.tr(_error!),
          ),
        ),
        RespondaButton(
          key: const Key('verify_identity_otp_button'),
          label: _verifying ? 'Verifying…' : 'Verify OTP',
          onPressed: _codeController.text.length == 6 && !_verifying
              ? _verify
              : null,
        ),
        TextButton(
          onPressed: () => widget.otpService.sendCode(widget.phoneNumber),
          child: const LocalizedText(
            'Resend code',
            style: TextStyle(color: AppColors.brand),
          ),
        ),
        const _PrototypeNotice(),
      ],
    );
  }
}

class _ValidIdScreen extends StatefulWidget {
  const _ValidIdScreen({required this.phoneNumber, required this.mediaPicker});

  final String phoneNumber;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<_ValidIdScreen> createState() => _ValidIdScreenState();
}

class _ValidIdScreenState extends State<_ValidIdScreen> {
  String? _idPath;
  bool _picking = false;

  Future<void> _pick(bool useCamera) async {
    if (_picking) {
      return;
    }
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
      if (mounted && path != null) {
        setState(() => _idPath = path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText('The ID image could not be opened.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _picking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _IdentityScaffold(
      step: 3,
      title: 'Upload a valid ID',
      subtitle:
          'Use a clear photo showing the complete ID and readable information.',
      children: [
        _MediaPreview(
          path: _idPath,
          icon: Icons.badge_outlined,
          emptyTitle: 'No ID uploaded',
          shape: BoxShape.rectangle,
        ),
        const _InfoCard(
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
                    builder: (_) => _FaceCaptureScreen(
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

class _FaceCaptureScreen extends StatefulWidget {
  const _FaceCaptureScreen({
    required this.phoneNumber,
    required this.idPath,
    required this.mediaPicker,
  });

  final String phoneNumber;
  final String idPath;
  final IdentityMediaPicker? mediaPicker;

  @override
  State<_FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<_FaceCaptureScreen>
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
    if (!_usesLiveCamera) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraController?.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    if (_initializingCamera) {
      return;
    }
    _initializingCamera = true;
    if (mounted) {
      setState(() => _cameraError = null);
    }
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
    if (_usesLiveCamera) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing) {
      return;
    }
    setState(() => _capturing = true);
    try {
      final path = widget.mediaPicker != null
          ? await widget.mediaPicker!(true)
          : (await _cameraController!.takePicture()).path;
      if (mounted && path != null) {
        setState(() => _facePath = path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText('The face photo could not be captured.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _capturing = false);
      }
    }
  }

  Future<void> _submit() async {
    if (_facePath == null || _submitting) {
      return;
    }
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
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            _VerificationSubmittedScreen(phoneNumber: widget.phoneNumber),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _IdentityScaffold(
      step: 4,
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
        const _InfoCard(
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

class _VerificationSubmittedScreen extends StatelessWidget {
  const _VerificationSubmittedScreen({required this.phoneNumber});

  final String phoneNumber;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 350),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                      color: AppColors.brandSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      color: AppColors.brand,
                      size: 46,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const LocalizedText(
                    'Verification pending',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  LocalizedText(
                    context.tr(
                      'Your account for {phone} was submitted. You can use RESPONDA while MDRRMO reviews your identity.',
                      values: {'phone': phoneNumber},
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 20 / 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.warningSoft,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const LocalizedText(
                      'You will receive a notification when the verification status changes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        height: 17 / 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  RespondaButton(
                    key: const Key('open_responda_after_identity_button'),
                    label: 'Open RESPONDA',
                    onPressed: () => Navigator.of(context)
                        .pushNamedAndRemoveUntil(AppRoutes.home, (_) => false),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityScaffold extends StatelessWidget {
  const _IdentityScaffold({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final int step;
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
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: AppColors.brand,
                            size: 19,
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
                        context.tr('{step} of 4', values: {'step': step}),
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
                      value: step / 4,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brandSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brand, size: 23),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                LocalizedText(
                  message,
                  style: const TextStyle(
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

class _PrototypeNotice extends StatelessWidget {
  const _PrototypeNotice();

  @override
  Widget build(BuildContext context) {
    return const LocalizedText(
      'Prototype mode: SMS delivery will be connected with the authentication backend. For testing, use OTP 123456.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 11,
        height: 16 / 11,
      ),
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

    Widget content;
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
          child: CameraPreview(camera),
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
      width: 230,
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.brand, width: 3),
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

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.path,
    required this.icon,
    required this.emptyTitle,
    required this.shape,
  });

  final String? path;
  final IconData icon;
  final String emptyTitle;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    final circular = shape == BoxShape.circle;
    final width = circular ? 210.0 : double.infinity;
    final height = circular ? 210.0 : 220.0;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.neutralSoft,
        shape: shape,
        borderRadius: circular ? null : BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: path == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.brand, size: 48),
                const SizedBox(height: 10),
                LocalizedText(
                  emptyTitle,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Image.file(File(path!), fit: BoxFit.cover),
    );
  }
}

InputDecoration _inputDecoration({
  required String hintText,
  String? prefixText,
  String? errorText,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixText: prefixText,
    errorText: errorText,
    filled: true,
    fillColor: AppColors.surface,
    counterText: '',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.brand, width: 2),
    ),
  );
}
