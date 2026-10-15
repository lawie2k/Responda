import 'package:flutter/material.dart';

import 'package:responda/core/constants/pantukan_barangays.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/widgets/identity_verification_widgets.dart';
import 'package:responda/features/onboarding/presentation/widgets/onboarding_step_scaffold.dart';

import 'verification_submitted_screen.dart';

class OptionalProfileScreen extends StatefulWidget {
  const OptionalProfileScreen({
    required this.phoneNumber,
    required this.privacyNoticeAcceptedAt,
    super.key,
  });

  final String phoneNumber;
  final DateTime privacyNoticeAcceptedAt;

  @override
  State<OptionalProfileScreen> createState() => _OptionalProfileScreenState();
}

class _OptionalProfileScreenState extends State<OptionalProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedBarangay;
  bool _saving = false;

  bool get _hasDetails =>
      _nameController.text.trim().isNotEmpty || _selectedBarangay != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    final accountController = AccountScope.maybeOf(context);
    if (accountController == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Account storage is not available.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    await accountController.completePhoneVerification(
      phoneNumber: widget.phoneNumber,
      privacyNoticeAcceptedAt: widget.privacyNoticeAcceptedAt,
      fullName: _nameController.text,
      barangay: _selectedBarangay ?? '',
    );
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
      title: 'Optional account details',
      subtitle: 'These details can help responders recognize your account, but they are not required.',
      children: [
        const IdentityInfoCard(
          icon: Icons.privacy_tip_outlined,
          title: 'You can skip this step',
          message: 'Leaving these fields empty will not prevent you from using RESPONDA or reporting an emergency.',
        ),
        const LocalizedText(
          'Full name (optional)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        TextField(
          key: const Key('optional_profile_name_field'),
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() {}),
          decoration: identityInputDecoration(hintText: 'Enter your full name'),
        ),
        const LocalizedText(
          'Barangay (optional)',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        DropdownButtonFormField<String>(
          key: const Key('optional_profile_barangay_field'),
          initialValue: _selectedBarangay,
          isExpanded: true,
          menuMaxHeight: 320,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: identityInputDecoration(
            hintText: context.tr('Select your barangay'),
          ),
          items: pantukanBarangays
              .map(
                (barangay) => DropdownMenuItem<String>(
                  value: barangay,
                  child: Text(barangay),
                ),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() => _selectedBarangay = value),
        ),
        RespondaButton(
          key: const Key('finish_account_setup_button'),
          label: _saving
              ? 'Saving…'
              : _hasDetails
              ? 'Save and continue'
              : 'Skip for now',
          onPressed: _saving ? null : _finish,
        ),
      ],
    );
  }
}
