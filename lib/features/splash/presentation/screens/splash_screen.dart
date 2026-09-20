import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../onboarding/presentation/screens/language_selection_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    this.destination = const LanguageSelectionScreen(),
    this.autoNavigate = true,
    super.key,
  });

  final Widget destination;
  final bool autoNavigate;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleNavigation();
  }

  @override
  void didUpdateWidget(covariant SplashScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.autoNavigate && widget.autoNavigate) {
      _scheduleNavigation();
    }
  }

  void _scheduleNavigation() {
    if (!widget.autoNavigate) {
      return;
    }
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), _openNextScreen);
  }

  void _openNextScreen() {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => widget.destination),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: ColoredBox(
          color: AppColors.background,
          child: Center(child: _SplashContent()),
        ),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Image(
          image: AssetImage('assets/images/responda_logo.png'),
          width: 150,
          height: 150,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(height: 18),
        LocalizedText(
          'RESPONDA',
          style: TextStyle(
            color: AppColors.brand,
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 47 / 34,
          ),
        ),
      ],
    );
  }
}
