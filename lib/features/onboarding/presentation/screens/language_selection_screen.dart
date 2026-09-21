import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/app_language_scope.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responda_button.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'identity_verification_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  AppLanguage _selectedLanguage = AppLanguage.english;
  bool _initializedLanguage = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedLanguage) {
      _selectedLanguage =
          AppLanguageScope.maybeOf(context)?.language ?? AppLanguage.english;
      _initializedLanguage = true;
    }
  }

  Future<void> _continue() async {
    if (_isSaving) {
      return;
    }
    setState(() => _isSaving = true);
    await AppLanguageScope.maybeOf(context)?.selectLanguage(_selectedLanguage);
    if (!mounted) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const IdentityVerificationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: 1,
      title: 'Choose your language',
      subtitle: 'Choose your language\nPilia ang imong pinulongan\nPiliin ang iyong wika',
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brandSoft,
              borderRadius: BorderRadius.circular(32),
            ),
            child: SvgPicture.asset(
              'assets/icons/language.svg',
              width: 50,
              height: 44,
            ),
          ),
        ),
        _LanguageButton(
          label: 'English',
          selected: _selectedLanguage == AppLanguage.english,
          onPressed: () => _select(AppLanguage.english),
        ),
        _LanguageButton(
          label: 'Filipino/Tagalog',
          selected: _selectedLanguage == AppLanguage.filipino,
          onPressed: () => _select(AppLanguage.filipino),
        ),
        _LanguageButton(
          label: 'Bisaya/Cebuano',
          selected: _selectedLanguage == AppLanguage.cebuano,
          onPressed: () => _select(AppLanguage.cebuano),
        ),
        RespondaButton(
          label: AppStrings(_selectedLanguage)
              .text(_isSaving ? 'Saving…' : 'Continue'),
          onPressed: _isSaving ? null : _continue,
        ),
      ],
    );
  }

  void _select(AppLanguage language) {
    setState(() => _selectedLanguage = language);
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return RespondaButton(
      label: label,
      onPressed: onPressed,
      style: selected
          ? RespondaButtonStyle.selected
          : RespondaButtonStyle.ghost,
    );
  }
}
