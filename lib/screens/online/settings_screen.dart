import 'dart:async';

import 'package:flutter/material.dart';

import 'package:responda/core/localization/app_language.dart';
import 'package:responda/core/localization/app_language_scope.dart';
import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/settings/app_settings_controller.dart';
import 'package:responda/core/settings/app_settings_scope.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:responda/features/reporting/data/offline_report_store.dart';
import 'package:responda/features/reporting/data/online_report_store.dart';
import 'package:responda/features/testing/data/testing_mode_controller.dart';
import 'package:responda/features/testing/presentation/testing_mode_scope.dart';
import 'package:responda/features/tutorial/data/home_tutorial_store.dart';

import 'account_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    this.onlineReportStore = const OnlineReportStore(),
    this.offlineReportStore = const OfflineReportStore(),
    this.locationService = const DeviceLocationService(),
    this.homeTutorialStore = const SharedPreferencesHomeTutorialStore(),
    this.onOutsidePantukanChanged,
    super.key,
  });

  final OnlineReportStore onlineReportStore;
  final OfflineReportStore offlineReportStore;
  final DeviceLocationService locationService;
  final HomeTutorialProgressStore homeTutorialStore;
  final ValueChanged<bool>? onOutsidePantukanChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = true;
  bool _updatingNotifications = false;
  bool _allowGps = true;
  bool _updatingGps = false;
  bool _checkingGpsPermission = false;
  bool _gpsPermissionChecked = false;
  bool _gpsPermissionGranted = true;
  bool _waitingForGpsPermission = false;
  bool _clearingReports = false;
  bool _resettingTestData = false;
  bool _updatingOutsideMode = false;
  bool _restartingTutorial = false;
  bool _outsidePantukan = false;
  AppLanguage _language = AppLanguage.english;
  AppSettingsController? _settingsController;
  GpsPreferenceController? _gpsPreferenceController;
  TestingModeController? _testingModeController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _language =
        AppLanguageScope.maybeOf(context)?.language ?? AppLanguage.english;
    _settingsController = AppSettingsScope.maybeOf(context);
    _notificationsEnabled =
        _settingsController?.notificationsEnabled ?? _notificationsEnabled;
    _gpsPreferenceController = GpsPreferenceScope.maybeOf(context);
    _allowGps = _gpsPreferenceController?.allowGps ?? true;
    if (!_gpsPermissionChecked && !_checkingGpsPermission) {
      _syncGpsPermission();
    }
    _testingModeController = TestingModeScope.maybeOf(context);
    _outsidePantukan =
        _testingModeController?.outsidePantukan ?? _outsidePantukan;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncGpsPermission(enableWhenGranted: _waitingForGpsPermission);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = AccountScope.maybeOf(context)?.profile;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: SingleChildScrollView(
            key: const Key('settings_scroll_view'),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SettingsHeader(),
                const SizedBox(height: 18),
                const _SectionLabel('ACCOUNT'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.manage_accounts_outlined,
                      title: 'Account management',
                      subtitle:
                          profile?.phoneNumber ??
                          'Phone number and identity verification',
                      value: profile?.status.label,
                      onTap: _openAccountManagement,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('PREFERENCES'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      key: const Key('language_settings_tile'),
                      icon: Icons.language_rounded,
                      title: 'Language',
                      subtitle: 'Language used throughout the app',
                      value: _language.displayName,
                      onTap: _showLanguagePicker,
                    ),
                    const _CardDivider(),
                    _SwitchTile(
                      icon: Icons.notifications_none_rounded,
                      title: 'Notifications',
                      subtitle: 'Report and emergency updates',
                      value: _notificationsEnabled,
                      onChanged: _updatingNotifications
                          ? null
                          : _setNotificationsEnabled,
                    ),
                    const _CardDivider(),
                    _SwitchTile(
                      key: const Key('gps_settings_switch_tile'),
                      icon: Icons.location_on_outlined,
                      title: 'Allow GPS',
                      subtitle: !_gpsPermissionGranted
                          ? 'Location permission is off. Tap to open phone settings'
                          : _allowGps
                          ? 'Use phone GPS for incident locations'
                          : 'RESPONDA will not access phone GPS',
                      value: _allowGps,
                      onChanged: _updatingGps || _checkingGpsPermission
                          ? null
                          : _setAllowGps,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('PRIVACY & DATA'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      key: const Key('privacy_data_tile'),
                      icon: Icons.shield_outlined,
                      title: 'Location and photo data',
                      subtitle: 'Learn how report information is used',
                      onTap: _showPrivacyInformation,
                    ),
                    const _CardDivider(),
                    _SettingsTile(
                      key: const Key('clear_local_reports_tile'),
                      icon: Icons.delete_outline_rounded,
                      title: 'Clear local reports',
                      subtitle: 'Remove saved drafts from this device',
                      destructive: true,
                      onTap: _clearingReports ? null : _confirmClearReports,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('ABOUT'),
                const SizedBox(height: 8),
                const _AboutCard(),
                const SizedBox(height: 18),
                const _SectionLabel('TESTING'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      key: const Key('toggle_outside_pantukan_tile'),
                      icon: _outsidePantukan
                          ? Icons.location_on_outlined
                          : Icons.location_off_outlined,
                      title: _outsidePantukan
                          ? 'Return to normal mode'
                          : 'Test outside Pantukan',
                      subtitle: _outsidePantukan
                          ? 'Restore normal reporting inside Pantukan'
                          : 'Show the screen that blocks report creation',
                      onTap: _updatingOutsideMode
                          ? null
                          : _toggleOutsidePantukan,
                    ),
                    const _CardDivider(),
                    _SettingsTile(
                      key: const Key('replay_home_tutorial_tile'),
                      icon: Icons.school_outlined,
                      title: 'Replay Home Tutorial',
                      subtitle: 'Show the guided Home screen tour again',
                      onTap: _restartingTutorial ? null : _replayHomeTutorial,
                    ),
                    const _CardDivider(),
                    _SettingsTile(
                      key: const Key('reset_test_onboarding_tile'),
                      icon: Icons.restart_alt_rounded,
                      title: 'Reset verification & setup',
                      subtitle: 'Clear identity verification, language, and GPS choice',
                      destructive: true,
                      onTap: _resettingTestData ? null : _confirmTestReset,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openAccountManagement() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AccountManagementScreen()),
    );
  }

  Future<void> _showLanguagePicker() async {
    final languageController = AppLanguageScope.maybeOf(context);
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => _LanguagePicker(selectedLanguage: _language),
    );
    if (selected == null || selected == _language || !mounted) {
      return;
    }

    setState(() => _language = selected);
    await languageController?.selectLanguage(selected);
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    if (_updatingNotifications) {
      return;
    }

    final previous = _notificationsEnabled;
    setState(() {
      _notificationsEnabled = value;
      _updatingNotifications = true;
    });
    try {
      await _settingsController?.setNotificationsEnabled(value);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _notificationsEnabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Could not save the notification setting.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingNotifications = false);
      }
    }
  }

  void _showPrivacyInformation() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _PrivacyInformationSheet(),
    );
  }

  Future<void> _confirmClearReports() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _ClearReportsSheet(),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _clearingReports = true);
    try {
      await Future.wait([
        widget.onlineReportStore.clearAll(),
        widget.offlineReportStore.clearAll(),
      ]);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Local reports cleared.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Could not clear local reports.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _clearingReports = false);
      }
    }
  }

  Future<void> _setAllowGps(bool value) async {
    if (_updatingGps) {
      return;
    }

    if (!value) {
      setState(() => _allowGps = false);
      await _gpsPreferenceController?.setAllowGps(false);
      return;
    }

    setState(() => _updatingGps = true);
    final permissionGranted = await widget.locationService
        .hasWhenInUsePermission();
    if (!mounted) {
      return;
    }

    if (!permissionGranted) {
      setState(() {
        _allowGps = false;
        _gpsPermissionGranted = false;
        _gpsPermissionChecked = true;
        _waitingForGpsPermission = true;
        _updatingGps = false;
      });
      await _gpsPreferenceController?.setAllowGps(false);
      final opened = await widget.locationService.openAppSettings();
      if (mounted && !opened) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: LocalizedText('Could not open the phone settings.'),
          ),
        );
      }
      return;
    }

    setState(() {
      _allowGps = true;
      _gpsPermissionGranted = true;
      _gpsPermissionChecked = true;
      _updatingGps = false;
    });
    await _gpsPreferenceController?.setAllowGps(true);
  }

  Future<void> _syncGpsPermission({bool enableWhenGranted = false}) async {
    if (_checkingGpsPermission) {
      return;
    }
    _checkingGpsPermission = true;
    final permissionWasDenied = _gpsPermissionChecked && !_gpsPermissionGranted;
    final permissionGranted = await widget.locationService
        .hasWhenInUsePermission();
    if (!mounted) {
      return;
    }

    final shouldEnable =
        permissionGranted && (enableWhenGranted || permissionWasDenied);
    setState(() {
      _checkingGpsPermission = false;
      _gpsPermissionChecked = true;
      _gpsPermissionGranted = permissionGranted;
      _waitingForGpsPermission = false;
      _allowGps =
          permissionGranted &&
          (shouldEnable || (_gpsPreferenceController?.allowGps ?? true));
    });

    if (!permissionGranted && (_gpsPreferenceController?.allowGps ?? false)) {
      await _gpsPreferenceController?.setAllowGps(false);
    } else if (shouldEnable) {
      await _gpsPreferenceController?.setAllowGps(true);
    }
  }

  Future<void> _confirmTestReset() async {
    final accountController = AccountScope.maybeOf(context);
    final languageController = AppLanguageScope.maybeOf(context);
    final gpsController = GpsPreferenceScope.maybeOf(context);
    final testingModeController = TestingModeScope.maybeOf(context);
    final navigator = Navigator.of(context);

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => const _TestResetSheet(),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _resettingTestData = true);
    unawaited(widget.homeTutorialStore.reset());
    await Future.wait([
      if (accountController != null) accountController.clearLocalSession(),
      if (languageController != null) languageController.resetSelection(),
      if (gpsController != null) gpsController.resetPreference(),
      if (testingModeController != null) testingModeController.reset(),
    ]);
    if (!mounted) {
      return;
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LanguageSelectionScreen()),
      (_) => false,
    );
  }

  Future<void> _replayHomeTutorial() async {
    if (_restartingTutorial) return;
    setState(() => _restartingTutorial = true);
    await widget.homeTutorialStore.reset();
    if (!mounted) return;
    Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
  }

  Future<void> _toggleOutsidePantukan() async {
    if (_updatingOutsideMode) return;
    final nextValue = !_outsidePantukan;
    setState(() => _updatingOutsideMode = true);
    try {
      await _testingModeController?.setOutsidePantukan(nextValue);
      if (!mounted) return;
      setState(() => _outsidePantukan = nextValue);
      widget.onOutsidePantukanChanged?.call(nextValue);
    } finally {
      if (mounted) setState(() => _updatingOutsideMode = false);
    }
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LocalizedText(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 23,
            fontWeight: FontWeight.w700,
            height: 29 / 23,
          ),
        ),
        SizedBox(height: 2),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return LocalizedText(
      label,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121C1C1E),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.value,
    this.destructive = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? value;
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.danger : AppColors.brand;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _IconBox(icon: icon, color: color),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LocalizedText(
                    title,
                    style: TextStyle(
                      color: destructive
                          ? AppColors.danger
                          : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  LocalizedText(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
            if (value != null) ...[
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 100),
                child: LocalizedText(
                  value!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 5),
            Icon(
              Icons.chevron_right_rounded,
              color: destructive ? AppColors.danger : AppColors.textSecondary,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyInformationSheet extends StatelessWidget {
  const _PrivacyInformationSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _IconBox(icon: Icons.shield_outlined),
                SizedBox(width: 12),
                Expanded(
                  child: LocalizedText(
                    'Location and photo data',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _PrivacyItem(
              icon: Icons.location_on_outlined,
              title: 'Location',
              description: 'Your selected incident location is attached to the report so responders can find the emergency.',
            ),
            const SizedBox(height: 12),
            const _PrivacyItem(
              icon: Icons.photo_camera_outlined,
              title: 'Photos',
              description: 'A photo is optional and is only attached when you choose or capture one for a report.',
            ),
            const SizedBox(height: 12),
            const _PrivacyItem(
              icon: Icons.phone_android_rounded,
              title: 'On this device',
              description: 'Saved report details remain on this phone until you clear local reports or uninstall the app.',
            ),
            const SizedBox(height: 20),
            RespondaButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  const _PrivacyItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.brand, size: 21),
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
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              LocalizedText(
                description,
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
    );
  }
}

class _ClearReportsSheet extends StatelessWidget {
  const _ClearReportsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const LocalizedText(
              'Clear local reports?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const LocalizedText(
              'This permanently removes online report history and offline saved reports from this phone. This cannot be undone.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 19 / 13,
              ),
            ),
            const SizedBox(height: 18),
            RespondaButton(
              key: const Key('confirm_clear_local_reports_button'),
              label: 'Clear reports',
              style: RespondaButtonStyle.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            RespondaButton(
              label: 'Cancel',
              style: RespondaButtonStyle.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _TestResetSheet extends StatelessWidget {
  const _TestResetSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.dangerSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restart_alt_rounded,
                color: AppColors.danger,
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            const LocalizedText(
              'Reset test data?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const LocalizedText(
              'This clears the saved identity verification, selected language, and RESPONDA GPS preference. Saved reports will not be deleted.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 19 / 13,
              ),
            ),
            const SizedBox(height: 18),
            RespondaButton(
              key: const Key('confirm_test_reset_button'),
              label: 'Reset and start over',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            RespondaButton(
              label: 'Cancel',
              style: RespondaButtonStyle.ghost,
              onPressed: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.selectedLanguage});

  final AppLanguage selectedLanguage;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText(
              'Choose language',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            for (final language in AppLanguage.values)
              _LanguageOption(
                language: language,
                selected: language == selectedLanguage,
              ),
          ],
        ),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({required this.language, required this.selected});

  final AppLanguage language;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => Navigator.of(context).pop(language),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.brandSoft : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.brand : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: LocalizedText(
                  language.displayName,
                  style: TextStyle(
                    color: selected ? AppColors.brand : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? AppColors.brand : AppColors.textSecondary,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                LocalizedText(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: .82,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeTrackColor: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.color = AppColors.brand});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color == AppColors.danger
            ? AppColors.dangerSoft
            : AppColors.brandSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _CardDivider extends StatelessWidget {
  const _CardDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: AppColors.border, height: 1, indent: 49);
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Image.asset(
              'assets/images/responda_logo.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'RESPONDA',
                  style: TextStyle(
                    color: AppColors.surface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                LocalizedText(
                  'Pantukan MDRRMO',
                  style: TextStyle(color: Color(0xFFF7DDE1), fontSize: 12),
                ),
              ],
            ),
          ),
          const LocalizedText(
            'Version 1.0.0',
            style: TextStyle(color: Color(0xFFF7DDE1), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
