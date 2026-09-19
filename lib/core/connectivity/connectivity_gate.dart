import 'package:flutter/material.dart';

import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/features/splash/presentation/screens/splash_screen.dart';
import 'package:responda/screens/offline/offline_main_shell.dart';
import 'package:responda/screens/online/main_shell.dart';

import 'connectivity_controller.dart';
import 'connectivity_scope.dart';

class ConnectivityGate extends StatefulWidget {
  const ConnectivityGate({this.initialItem = RespondaNavItem.home, super.key});

  final RespondaNavItem initialItem;

  @override
  State<ConnectivityGate> createState() => _ConnectivityGateState();
}

class _ConnectivityGateState extends State<ConnectivityGate> {
  bool? _wasOffline;
  bool _dialogScheduled = false;
  bool _dialogVisible = false;
  bool _dialogDismissScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = ConnectivityScope.of(context);
    if (!controller.hasStatus) {
      return;
    }

    final isOffline = controller.isOffline;
    if (isOffline && _wasOffline != true) {
      _scheduleOfflineDialog(controller);
    } else if (!isOffline && _dialogVisible) {
      _scheduleDialogDismissal(controller);
    }
    _wasOffline = isOffline;
  }

  void _scheduleDialogDismissal(ConnectivityController controller) {
    if (_dialogDismissScheduled) {
      return;
    }
    _dialogDismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dialogDismissScheduled = false;
      if (mounted && _dialogVisible && !controller.isOffline) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
    });
  }

  void _scheduleOfflineDialog(ConnectivityController controller) {
    if (_dialogScheduled || _dialogVisible) {
      return;
    }
    _dialogScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _dialogScheduled = false;
      if (!mounted || !controller.isOffline) {
        return;
      }
      _dialogVisible = true;
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (_) => const _OfflineDetectedDialog(),
      );
      _dialogVisible = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = ConnectivityScope.of(context);
    if (!controller.hasStatus) {
      return const SplashScreen(autoNavigate: false);
    }

    return controller.isOnline == true
        ? MainShell(initialItem: widget.initialItem)
        : OfflineMainShell(initialItem: widget.initialItem);
  }
}

class _OfflineDetectedDialog extends StatelessWidget {
  const _OfflineDetectedDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/no-internet.gif',
                key: const Key('offline_notice_sprite'),
                width: 150,
                height: 218,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
              const SizedBox(height: 6),
              const Text(
                "You're Offline",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'No internet connection was detected. You can still create a report, save it on this phone, and hand it off through SMS.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B6B70),
                  fontSize: 13,
                  height: 18 / 13,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  key: const Key('dismiss_offline_notice'),
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF7A1F2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Text(
                    'Continue Offline',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
