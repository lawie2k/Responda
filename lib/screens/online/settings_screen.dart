import 'package:flutter/material.dart';

import 'package:responda/core/localization/app_language.dart';
import 'package:responda/core/localization/app_language_scope.dart';
import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/identity/presentation/account_scope.dart';

import 'account_management_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _offlineDraftsEnabled = true;
  bool _allowGps = true;
  bool _updatingGps = false;
  AppLanguage _language = AppLanguage.english;
  GpsPreferenceController? _gpsPreferenceController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _language =
        AppLanguageScope.maybeOf(context)?.language ?? AppLanguage.english;
    _gpsPreferenceController = GpsPreferenceScope.maybeOf(context);
    _allowGps = _gpsPreferenceController?.allowGps ?? true;
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
                      onChanged: (value) =>
                          setState(() => _notificationsEnabled = value),
                    ),
                    const _CardDivider(),
                    _SwitchTile(
                      icon: Icons.location_on_outlined,
                      title: 'Allow GPS',
                      subtitle: _allowGps
                          ? 'Use phone GPS for incident locations'
                          : 'RESPONDA will not access phone GPS',
                      value: _allowGps,
                      onChanged: _updatingGps ? null : _setAllowGps,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('REPORTING & SAFETY'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SwitchTile(
                      icon: Icons.save_outlined,
                      title: 'Save drafts offline',
                      subtitle: 'Keep unfinished reports on this device',
                      value: _offlineDraftsEnabled,
                      onChanged: (value) =>
                          setState(() => _offlineDraftsEnabled = value),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('PRIVACY & DATA'),
                const SizedBox(height: 8),
                const _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.shield_outlined,
                      title: 'Location and photo data',
                      subtitle: 'Learn how report information is used',
                    ),
                    _CardDivider(),
                    _SettingsTile(
                      icon: Icons.delete_outline_rounded,
                      title: 'Clear local reports',
                      subtitle: 'Remove saved drafts from this device',
                      destructive: true,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const _SectionLabel('ABOUT'),
                const SizedBox(height: 8),
                const _AboutCard(),
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
    await AppLanguageScope.maybeOf(context)?.selectLanguage(selected);
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
    final permissionGranted = await const DeviceLocationService()
        .requestWhenInUsePermission();
    if (!mounted) {
      return;
    }

    if (!permissionGranted) {
      setState(() {
        _allowGps = false;
        _updatingGps = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permission was not allowed in your phone settings.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _allowGps = true;
      _updatingGps = false;
    });
    await _gpsPreferenceController?.setAllowGps(true);
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
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
    return Text(
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
                  Text(
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
                  Text(
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
                child: Text(
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
            const Text(
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
                child: Text(
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
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
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
                Text(
                  'RESPONDA',
                  style: TextStyle(
                    color: AppColors.surface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pantukan MDRRMO',
                  style: TextStyle(color: Color(0xFFF7DDE1), fontSize: 12),
                ),
              ],
            ),
          ),
          const Text(
            'Version 1.0.0',
            style: TextStyle(color: Color(0xFFF7DDE1), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
