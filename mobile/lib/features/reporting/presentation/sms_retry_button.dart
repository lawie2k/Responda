import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/network/responda_api_client.dart';
import '../../onboarding/presentation/account_scope.dart';
import '../data/offline_report_store.dart';
import '../data/offline_sms_handoff.dart';

class SmsRetryButton extends StatefulWidget {
  const SmsRetryButton({required this.report, super.key});
  final SavedOfflineReport report;
  @override
  State<SmsRetryButton> createState() => _SmsRetryButtonState();
}

class _SmsRetryButtonState extends State<SmsRetryButton> {
  bool _busy = false;
  Future<void> _open() async {
    setState(() => _busy = true);
    try {
      final account = AccountScope.maybeOf(context);
      if (account == null) {
        throw const RespondaApiException(
          'Sign in to the original account first.',
        );
      }
      final report = await account.prepareSmsRetry(widget.report);
      if (!await OfflineSmsHandoff().openComposer(report)) {
        throw const RespondaApiException(
          'The SMS app could not be opened. Your saved report is still on this phone.',
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LocalizedText(
              error is RespondaApiException ? error.message : 'The SMS draft could not be prepared. Your saved report is still on this phone.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _busy ? null : _open,
    icon: const Icon(Icons.sms_outlined),
    label: LocalizedText(_busy ? 'Preparing SMS…' : 'Open SMS draft'),
  );
}
