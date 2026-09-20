import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';

import '../offline/offline_sms_gateway_screen.dart';
import '../shared/reporting/incident_location_screen.dart';
import '../shared/reporting/incident_type_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({this.flowMode = ReportFlowMode.online, super.key});

  final ReportFlowMode flowMode;

  static const _incidentTypes = [
    (
      IncidentType.accident,
      'Accident',
      'assets/icons/incident_accident.svg',
      34.0,
      27.0,
    ),
    (
      IncidentType.flood,
      'Flood',
      'assets/icons/incident_flood.svg',
      35.0,
      28.0,
    ),
    (IncidentType.fire, 'Fire', 'assets/icons/incident_fire.svg', 20.0, 27.0),
    (
      IncidentType.drowning,
      'Drowning',
      'assets/icons/report_drowning.svg',
      28.0,
      23.0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(isOffline: flowMode.isOffline),
                const SizedBox(height: 14),
                _EmergencyHero(onReport: () => _openReport(context)),
                const SizedBox(height: 14),
                const LocalizedText(
                  'Quick incident type',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    height: 22 / 16,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _incidentTypes
                      .map(
                        (item) => _IncidentCard(
                          label: item.$2,
                          asset: item.$3,
                          iconWidth: item.$4,
                          iconHeight: item.$5,
                          onTap: () =>
                              _openReport(context, initialType: item.$1),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                const _LocationCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openReport(BuildContext context, {IncidentType? initialType}) {
    if (flowMode.isOffline) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => OfflineSmsGatewayScreen(initialType: initialType),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => initialType == null
            ? IncidentTypeScreen(flowMode: flowMode)
            : IncidentLocationScreen(
                draft: ReportDraft(incidentType: initialType),
                flowMode: flowMode,
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 41,
      child: Row(
        children: [
          Image.asset('assets/images/responda_logo.png', width: 40, height: 40),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'RESPONDA',
                  style: TextStyle(
                    color: AppColors.brand,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 25 / 18,
                  ),
                ),
                LocalizedText(
                  'MDRRMO Pantukan',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 15 / 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 28,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isOffline ? AppColors.warningSoft : AppColors.successSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                if (isOffline)
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: AppColors.warning,
                    size: 13,
                  )
                else
                  SvgPicture.asset(
                    'assets/icons/online_dot.svg',
                    width: 7,
                    height: 7,
                  ),
                const SizedBox(width: 6),
                LocalizedText(
                  isOffline ? 'Offline' : 'Online',
                  style: TextStyle(
                    color: isOffline ? AppColors.warning : AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _EmergencyHero extends StatelessWidget {
  const _EmergencyHero({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 211,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            height: 211,
            padding: const EdgeInsets.fromLTRB(120, 20, 13, 16),
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 210,
                  height: 72,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: LocalizedText(
                      'Need Emergency\nAssistance?',
                      style: TextStyle(
                        color: AppColors.surface,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 36 / 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const SizedBox(
                  width: 210,
                  height: 36,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: 210,
                      child: LocalizedText(
                        'Send a structured report with your GPS location.',
                        style: TextStyle(
                          color: AppColors.heroText,
                          fontSize: 13,
                          height: 18 / 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                RespondaButton(
                  label: 'REPORT AN EMERGENCY',
                  height: 41,
                  style: RespondaButtonStyle.secondary,
                  onPressed: onReport,
                ),
              ],
            ),
          ),
          Positioned(
            left: -3,
            top: -45,
            child: Image.asset(
              'assets/images/welcome.gif',
              width: 136,
              height: 256,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({
    required this.label,
    required this.asset,
    required this.iconWidth,
    required this.iconHeight,
    required this.onTap,
  });

  final String label;
  final String asset;
  final double iconWidth;
  final double iconHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        height: 112,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x141C1C1E),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFCF6F7),
                borderRadius: BorderRadius.circular(14),
              ),
              child: SvgPicture.asset(
                asset,
                width: iconWidth,
                height: iconHeight,
              ),
            ),
            const SizedBox(height: 8),
            LocalizedText(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 15 / 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationCard extends StatefulWidget {
  const _LocationCard();

  @override
  State<_LocationCard> createState() => _LocationCardState();
}

enum _LocationCardStatus {
  gpsNotAllowed,
  loading,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
  unavailable,
}

class _LocationCardState extends State<_LocationCard>
    with WidgetsBindingObserver {
  static const _locationService = DeviceLocationService();

  _LocationCardStatus _status = _LocationCardStatus.loading;
  DeviceLocationData? _location;
  GpsPreferenceController? _gpsPreferenceController;
  bool? _lastAllowGps;
  bool _openedSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gpsPreferenceController = GpsPreferenceScope.maybeOf(context);
    final allowGps = _gpsPreferenceController?.allowGps ?? true;
    if (_lastAllowGps == allowGps) {
      return;
    }

    _lastAllowGps = allowGps;
    if (!allowGps) {
      setState(() {
        _location = null;
        _status = _LocationCardStatus.gpsNotAllowed;
      });
      return;
    }

    _loadLocation(requestPermission: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _openedSettings &&
        _isGpsAllowed) {
      _openedSettings = false;
      _loadLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _status == _LocationCardStatus.loading ? null : _handleTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 95),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            boxShadow: const [
              BoxShadow(
                color: Color(0x141C1C1E),
                blurRadius: 6,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: LocalizedText(
                      _status == _LocationCardStatus.gpsNotAllowed
                          ? 'Allow GPS'
                          : 'Current GPS Location',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 22 / 16,
                      ),
                    ),
                  ),
                  _StatusIcon(status: _status),
                ],
              ),
              const SizedBox(height: 4),
              LocalizedText(
                _details(context),
                style: TextStyle(
                  color: _status == _LocationCardStatus.ready
                      ? AppColors.textSecondary
                      : AppColors.brand,
                  fontSize: 12,
                  height: 17 / 12,
                  fontWeight: _status == _LocationCardStatus.ready
                      ? FontWeight.w400
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _details(BuildContext context) {
    final location = _location;
    if (_status == _LocationCardStatus.ready && location != null) {
      return '${context.tr('Latitude')}: ${location.latitude.toStringAsFixed(6)}\n'
          '${context.tr('Longitude')}: ${location.longitude.toStringAsFixed(6)}  '
          '·  ±${location.accuracy.toStringAsFixed(0)} m';
    }

    return switch (_status) {
      _LocationCardStatus.gpsNotAllowed =>
        'GPS is off in RESPONDA. Tap to allow GPS.',
      _LocationCardStatus.loading => 'Getting location from this device…',
      _LocationCardStatus.serviceDisabled =>
        'Location Services are off. Tap to open settings.',
      _LocationCardStatus.permissionDenied =>
        'Tap to allow location access for RESPONDA.',
      _LocationCardStatus.permissionDeniedForever =>
        'Location access is blocked. Tap to open app settings.',
      _LocationCardStatus.timedOut =>
        'GPS took too long to respond. Tap to try again.',
      _LocationCardStatus.unavailable =>
        'Unable to read GPS location. Tap to try again.',
      _LocationCardStatus.ready => '',
    };
  }

  Future<void> _loadLocation({bool requestPermission = false}) async {
    if (!_isGpsAllowed) {
      if (mounted) {
        setState(() {
          _status = _LocationCardStatus.gpsNotAllowed;
          _location = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _status = _LocationCardStatus.loading;
        _location = null;
      });
    }

    try {
      final location = await _locationService.getCurrentLocation(
        requestPermission: requestPermission,
      );
      if (!mounted || !_isGpsAllowed) {
        return;
      }
      setState(() {
        _location = location;
        _status = _LocationCardStatus.ready;
      });
    } on DeviceLocationException catch (error) {
      if (!mounted || !_isGpsAllowed) {
        return;
      }
      setState(() {
        _location = null;
        _status = switch (error.problem) {
          DeviceLocationProblem.serviceDisabled =>
            _LocationCardStatus.serviceDisabled,
          DeviceLocationProblem.permissionDenied =>
            _LocationCardStatus.permissionDenied,
          DeviceLocationProblem.permissionDeniedForever =>
            _LocationCardStatus.permissionDeniedForever,
          DeviceLocationProblem.timedOut => _LocationCardStatus.timedOut,
          DeviceLocationProblem.unavailable => _LocationCardStatus.unavailable,
        };
      });
    }
  }

  Future<void> _handleTap() async {
    switch (_status) {
      case _LocationCardStatus.gpsNotAllowed:
        final permissionGranted = await _locationService
            .requestWhenInUsePermission();
        if (!mounted || !permissionGranted) {
          return;
        }
        final controller = _gpsPreferenceController;
        if (controller == null) {
          _lastAllowGps = true;
          await _loadLocation();
        } else {
          await controller.setAllowGps(true);
        }
        return;
      case _LocationCardStatus.serviceDisabled:
        _openedSettings = true;
        await _locationService.openLocationSettings();
        return;
      case _LocationCardStatus.permissionDeniedForever:
        _openedSettings = true;
        await _locationService.openAppSettings();
        return;
      case _LocationCardStatus.permissionDenied:
        await _loadLocation(requestPermission: true);
        return;
      case _LocationCardStatus.ready:
      case _LocationCardStatus.timedOut:
      case _LocationCardStatus.unavailable:
        await _loadLocation();
        return;
      case _LocationCardStatus.loading:
        return;
    }
  }

  bool get _isGpsAllowed => _gpsPreferenceController?.allowGps ?? true;
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final _LocationCardStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == _LocationCardStatus.loading) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.brand,
        ),
      );
    }

    return Icon(
      switch (status) {
        _LocationCardStatus.gpsNotAllowed => Icons.location_off_rounded,
        _LocationCardStatus.ready => Icons.my_location_rounded,
        _LocationCardStatus.serviceDisabled => Icons.location_disabled_rounded,
        _LocationCardStatus.permissionDenied => Icons.location_on_outlined,
        _LocationCardStatus.permissionDeniedForever => Icons.settings_rounded,
        _LocationCardStatus.timedOut => Icons.refresh_rounded,
        _LocationCardStatus.unavailable => Icons.refresh_rounded,
        _LocationCardStatus.loading => Icons.my_location_rounded,
      },
      size: 20,
      color: status == _LocationCardStatus.ready
          ? AppColors.success
          : AppColors.brand,
    );
  }
}
