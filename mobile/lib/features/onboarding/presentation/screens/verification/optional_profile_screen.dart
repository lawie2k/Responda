import 'package:flutter/material.dart';

import 'package:responda/core/constants/pantukan_barangays.dart';
import 'package:responda/core/network/responda_api_client.dart';
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

  final String? phoneNumber;
  final DateTime privacyNoticeAcceptedAt;

  @override
  State<OptionalProfileScreen> createState() => _OptionalProfileScreenState();
}

class _OptionalProfileScreenState extends State<OptionalProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedBarangay;
  bool _saving = false;
  bool _initialized = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final profile = AccountScope.maybeOf(context)?.profile;
    _nameController.text = profile?.fullName ?? '';
    final barangay = profile?.barangay;
    _selectedBarangay = pantukanBarangays.contains(barangay) ? barangay : null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    if (_formKey.currentState?.validate() != true) return;
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
    try {
      if (widget.phoneNumber == null) {
        await accountController.completeBetaProfile(
          privacyNoticeAcceptedAt: widget.privacyNoticeAcceptedAt,
          fullName: _nameController.text.trim(),
          barangay: _selectedBarangay!,
        );
      } else {
        await accountController.completePhoneVerification(
          phoneNumber: widget.phoneNumber!,
          privacyNoticeAcceptedAt: widget.privacyNoticeAcceptedAt,
          fullName: _nameController.text.trim(),
          barangay: _selectedBarangay!,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => VerificationSubmittedScreen(
            phoneNumber: widget.phoneNumber,
            isBetaLocalSetup: widget.phoneNumber == null,
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is RespondaApiException
              ? error.message
              : 'Could not save your account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      step: widget.phoneNumber == null ? 3 : 5,
      title: 'Account details',
      subtitle: 'Add your name and barangay so responders can recognize your account.',
      children: [
        const IdentityInfoCard(
          icon: Icons.privacy_tip_outlined,
          title: 'Both details are required',
          message: 'Enter your name and choose your barangay to finish setting up your account.',
        ),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LocalizedText(
                'Name',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextFormField(
                key: const Key('optional_profile_name_field'),
                controller: _nameController,
                maxLength: 150,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Enter your full name.',
                decoration: identityInputDecoration(hintText: ''),
              ),
              const LocalizedText(
                'Barangay',
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
                validator: (value) =>
                    value != null ? null : 'Select your barangay.',
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
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.brand),
                  ),
                ),
              RespondaButton(
                key: const Key('finish_account_setup_button'),
                label: _saving ? 'Saving…' : 'Save and continue',
                onPressed: _saving ? null : _finish,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
