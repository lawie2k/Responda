import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/localization/app_language.dart';
import '../../../../core/localization/app_language_scope.dart';
import '../../../../core/navigation/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responda_button.dart';

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
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 350),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
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
                      const SizedBox(height: 14),
                      const Text(
                        'Choose your language\n'
                        'Pilia ang imong pinulongan\n'
                        'Piliin ang iyong wika',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 21 / 15,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _LanguageButton(
                        label: 'English',
                        selected: _selectedLanguage == AppLanguage.english,
                        onPressed: () => _select(AppLanguage.english),
                      ),
                      const SizedBox(height: 14),
                      _LanguageButton(
                        label: 'Filipino/Tagalog',
                        selected: _selectedLanguage == AppLanguage.filipino,
                        onPressed: () => _select(AppLanguage.filipino),
                      ),
                      const SizedBox(height: 14),
                      _LanguageButton(
                        label: 'Bisaya/Cebuano',
                        selected: _selectedLanguage == AppLanguage.cebuano,
                        onPressed: () => _select(AppLanguage.cebuano),
                      ),
                      const SizedBox(height: 14),
                      RespondaButton(
                        label: _isSaving ? 'Saving…' : 'Continue',
                        onPressed: _isSaving ? null : _continue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
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
