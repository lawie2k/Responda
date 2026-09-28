import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/location/gps_accuracy_quality.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/core/widgets/report_step_scaffold.dart';
import 'package:responda/core/widgets/responda_button.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';

import 'report_details_screen.dart';

typedef ReportLocationLoader = Future<DeviceLocationData> Function();

class IncidentLocationScreen extends StatefulWidget {
  const IncidentLocationScreen({
    required this.draft,
    this.flowMode = ReportFlowMode.online,
    this.loadLocation,
    this.onOpenSettings,
    this.returnToReview = false,
    super.key,
  });

  final ReportDraft draft;
  final ReportFlowMode flowMode;
  final ReportLocationLoader? loadLocation;
  final VoidCallback? onOpenSettings;
  final bool returnToReview;

  @override
  State<IncidentLocationScreen> createState() => _IncidentLocationScreenState();
}

class _IncidentLocationScreenState extends State<IncidentLocationScreen> {
  static const _locationService = DeviceLocationService();

  final _landmarkController = TextEditingController();
  final _landmarkFocus = FocusNode();
  final _mapController = MapController();
  DeviceLocationData? _gpsLocation;
  DeviceLocationData? _location;
  DeviceLocationProblem? _problem;
  bool _isLoading = false;
  bool _mapReady = false;
  bool _selectionMoved = false;
  bool _gpsDisabled = false;
  bool _autoLocationAttempted = false;
  bool _landmarkEntryEnabled = false;
  GpsPreferenceController? _gpsPreferenceController;

  @override
  void initState() {
    super.initState();
    _landmarkController.text = widget.draft.landmark;
    _landmarkEntryEnabled = widget.draft.landmark.trim().isNotEmpty;
    if (widget.draft.hasLocation) {
      _location = DeviceLocationData(
        latitude: widget.draft.latitude!,
        longitude: widget.draft.longitude!,
        accuracy: widget.draft.locationAccuracy ?? 0,
        timestamp: widget.draft.locationCapturedAt ?? DateTime.now(),
      );
      _gpsLocation = _location;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gpsPreferenceController = GpsPreferenceScope.maybeOf(context);
    final allowGps = _gpsPreferenceController?.allowGps ?? true;

    if (!allowGps) {
      if (!_gpsDisabled || _location != null || _gpsLocation != null) {
        setState(() {
          _gpsDisabled = true;
          _isLoading = false;
          _gpsLocation = null;
          _location = null;
          _problem = null;
        });
      }
      return;
    }

    if (_gpsDisabled) {
      setState(() => _gpsDisabled = false);
    }
    if (!widget.draft.hasLocation && !_autoLocationAttempted) {
      _autoLocationAttempted = true;
      _refreshLocation();
    }
  }

  @override
  void dispose() {
    _landmarkController.dispose();
    _landmarkFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final location = _location;

    return ReportStepScaffold(
      title: 'Incident Location',
      step: 2,
      totalSteps: widget.flowMode.totalFormSteps,
      children: [
        if (widget.flowMode.isOffline)
          const _MessageCard(
            title: 'GPS works without internet',
            message: 'RESPONDA uses satellite GPS offline. Without cellular or Wi-Fi assistance, stay in an open area while it searches for up to 90 seconds.',
            color: AppColors.warningSoft,
          ),
        _LocationTag(
          isLoading: _isLoading,
          hasLocation: location != null,
          gpsDisabled: _gpsDisabled,
          accuracy: location?.accuracy,
        ),
        if (!widget.flowMode.isOffline)
          _GpsMapPreview(
            controller: _mapController,
            gpsLocation: _gpsLocation,
            selectedLocation: location,
            gpsDisabled: _gpsDisabled,
            onMapReady: _handleMapReady,
            onPointChanged: _selectMapPoint,
          ),
        if (_gpsDisabled)
          _MessageCard(
            key: const Key('report_gps_settings_card'),
            title: 'Allow GPS',
            message:
                'GPS is off in RESPONDA. Tap to open Settings for this report.',
            color: AppColors.warningSoft,
            onTap: _openSettings,
          )
        else if (location != null)
          _LocationCard(location: location, selectedFromMap: _selectionMoved)
        else if (_problem != null)
          _LocationErrorCard(problem: _problem!)
        else
          _DetectingLocationCard(isOffline: widget.flowMode.isOffline),
        if (location != null && location.accuracy >= 50)
          _GpsAccuracyWarning(accuracy: location.accuracy),
        Row(
          children: [
            Expanded(
              child: RespondaButton(
                key: _gpsDisabled
                    ? const Key('report_open_settings_button')
                    : null,
                label: _gpsDisabled
                    ? 'Open Settings'
                    : _isLoading
                    ? 'Refreshing…'
                    : 'Refresh',
                style: RespondaButtonStyle.ghost,
                onPressed: _isLoading
                    ? null
                    : _gpsDisabled
                    ? _openSettings
                    : _refreshLocation,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: RespondaButton(
                label: 'Use This Location',
                onPressed: location == null ? null : _continue,
              ),
            ),
          ],
        ),
        TextField(
          key: const Key('landmark_input'),
          controller: _landmarkController,
          focusNode: _landmarkFocus,
          enabled: _landmarkEntryEnabled,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.tr('Landmark'),
            hintText: context.tr('e.g. Kingking Highway'),
            helperText: _landmarkEntryEnabled
                ? context.tr('Type a nearby place responders can recognize.')
                : context.tr(
                    'Tap Enter Landmark Manually to unlock this field.',
                  ),
            filled: true,
            fillColor: _landmarkEntryEnabled
                ? AppColors.surface
                : AppColors.neutralSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.brand, width: 2),
            ),
          ),
        ),
        RespondaButton(
          key: const Key('enable_landmark_input_button'),
          label: 'Enter Landmark Manually',
          style: RespondaButtonStyle.secondary,
          onPressed: _enableLandmarkEntry,
        ),
      ],
    );
  }

  Future<void> _refreshLocation() async {
    if (_isLoading || !_isGpsAllowed) {
      if (mounted && !_isGpsAllowed) {
        setState(() {
          _gpsDisabled = true;
          _gpsLocation = null;
          _location = null;
        });
      }
      return;
    }

    _autoLocationAttempted = true;
    setState(() {
      _gpsDisabled = false;
      _isLoading = true;
      _problem = null;
    });

    try {
      final loader =
          widget.loadLocation ??
          () => _locationService.getCurrentLocation(
            requestPermission: true,
            timeLimit: widget.flowMode.isOffline
                ? DeviceLocationService.satelliteFixTimeout
                : DeviceLocationService.assistedFixTimeout,
          );
      final location = await loader();
      if (!mounted || !_isGpsAllowed) {
        return;
      }
      setState(() {
        _gpsLocation = location;
        _location = location;
        _selectionMoved = false;
      });
      _moveMapTo(location);
    } on DeviceLocationException catch (error) {
      if (!mounted || !_isGpsAllowed) {
        return;
      }
      setState(() => _problem = error.problem);
    } catch (_) {
      if (!mounted || !_isGpsAllowed) {
        return;
      }
      setState(() => _problem = DeviceLocationProblem.unavailable);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _openSettings() {
    widget.onOpenSettings?.call();
  }

  bool get _isGpsAllowed => _gpsPreferenceController?.allowGps ?? true;

  void _enableLandmarkEntry() {
    if (!_landmarkEntryEnabled) {
      setState(() => _landmarkEntryEnabled = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _landmarkFocus.requestFocus();
      }
    });
  }

  void _continue() {
    final location = _location;
    if (location == null) {
      return;
    }

    final draft = widget.draft.copyWith(
      latitude: location.latitude,
      longitude: location.longitude,
      locationAccuracy: location.accuracy,
      locationCapturedAt: location.timestamp,
      landmark: _landmarkController.text.trim(),
    );

    if (widget.returnToReview) {
      Navigator.of(context).pop(draft);
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReportDetailsScreen(draft: draft, flowMode: widget.flowMode),
      ),
    );
  }

  void _handleMapReady() {
    _mapReady = true;
    final location = _location;
    if (location != null) {
      _moveMapTo(location);
    }
  }

  void _moveMapTo(DeviceLocationData location) {
    if (!_mapReady) {
      return;
    }
    _mapController.move(
      LatLng(location.latitude, location.longitude),
      _zoomForAccuracy(location),
    );
  }

  double _zoomForAccuracy(DeviceLocationData location) {
    final accuracy = math.max(location.accuracy, 1);
    final latitudeScale = math.cos(location.latitude * math.pi / 180).abs();
    final zoom =
        math.log(156543.03392 * latitudeScale * 55 / accuracy) / math.ln2;
    return zoom.clamp(10, 19).toDouble();
  }

  void _selectMapPoint(LatLng point) {
    final gpsLocation = _gpsLocation;
    if (gpsLocation == null) {
      return;
    }

    final gpsPoint = LatLng(gpsLocation.latitude, gpsLocation.longitude);
    final moved = const Distance()(gpsPoint, point) > 5;
    setState(() {
      _selectionMoved = moved;
      _location = moved
          ? DeviceLocationData(
              latitude: point.latitude,
              longitude: point.longitude,
              accuracy: 0,
              timestamp: DateTime.now(),
            )
          : gpsLocation;
    });
  }
}

class _LocationTag extends StatelessWidget {
  const _LocationTag({
    required this.isLoading,
    required this.hasLocation,
    required this.gpsDisabled,
    required this.accuracy,
  });

  final bool isLoading;
  final bool hasLocation;
  final bool gpsDisabled;
  final double? accuracy;

  @override
  Widget build(BuildContext context) {
    final hasLowAccuracy = hasLocation && (accuracy ?? 0) >= 50;
    final hasVeryLowAccuracy = hasLowAccuracy && (accuracy ?? 0) >= 200;
    final label = gpsDisabled
        ? 'Allow GPS'
        : isLoading
        ? 'Detecting location'
        : hasLocation
        ? hasVeryLowAccuracy
              ? 'Very low GPS accuracy'
              : hasLowAccuracy
              ? 'Low GPS accuracy'
              : 'Location detected'
        : 'Location unavailable';
    final color = hasVeryLowAccuracy
        ? AppColors.danger
        : hasLocation && !hasLowAccuracy
        ? AppColors.success
        : AppColors.warning;
    final background = hasVeryLowAccuracy
        ? AppColors.dangerSoft
        : hasLocation && !hasLowAccuracy
        ? AppColors.successSoft
        : AppColors.warningSoft;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            LocalizedText(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsAccuracyWarning extends StatelessWidget {
  const _GpsAccuracyWarning({required this.accuracy});

  final double accuracy;

  @override
  Widget build(BuildContext context) {
    final roundedAccuracy = accuracy.round();
    final isVeryLow = accuracy >= 200;
    final color = isVeryLow ? AppColors.danger : AppColors.warning;
    final background = isVeryLow ? AppColors.dangerSoft : AppColors.warningSoft;
    final title = isVeryLow ? 'Very low GPS accuracy' : 'Low GPS accuracy';
    final message = isVeryLow
        ? context.tr(
            'GPS is not good (±{accuracy} m) and may point to the wrong area. Enter a clear landmark, move outdoors, and tap Refresh before continuing.',
            values: {'accuracy': roundedAccuracy},
          )
        : context.tr(
            'GPS accuracy is only okay (±{accuracy} m). Enter a nearby landmark to make the incident location more certain, or move outside and tap Refresh.',
            values: {'accuracy': roundedAccuracy},
          );

    return Container(
      key: Key(
        isVeryLow
            ? 'very_low_gps_accuracy_warning'
            : 'low_gps_accuracy_warning',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isVeryLow ? Icons.gps_off_rounded : Icons.gps_not_fixed_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
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

class _GpsMapPreview extends StatelessWidget {
  const _GpsMapPreview({
    required this.controller,
    required this.gpsLocation,
    required this.selectedLocation,
    required this.gpsDisabled,
    required this.onMapReady,
    required this.onPointChanged,
  });

  static const _pantukanCenter = LatLng(7.135421, 125.912300);

  final MapController controller;
  final DeviceLocationData? gpsLocation;
  final DeviceLocationData? selectedLocation;
  final bool gpsDisabled;
  final VoidCallback onMapReady;
  final ValueChanged<LatLng> onPointChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 230,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFEDE9E5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              ignoring: gpsLocation == null,
              child: FlutterMap(
                mapController: controller,
                options: MapOptions(
                  initialCenter: selectedLocation == null
                      ? _pantukanCenter
                      : LatLng(
                          selectedLocation!.latitude,
                          selectedLocation!.longitude,
                        ),
                  initialZoom: 17,
                  minZoom: 6,
                  maxZoom: 19,
                  onMapReady: onMapReady,
                  onTap: (_, point) {
                    controller.move(point, controller.camera.zoom);
                    onPointChanged(point);
                  },
                  onPositionChanged: (camera, hasGesture) {
                    if (hasGesture) {
                      onPointChanged(camera.center);
                    }
                  },
                  interactionOptions: const InteractionOptions(
                    flags:
                        InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.responda',
                    maxNativeZoom: 19,
                  ),
                  if (gpsLocation != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          key: const Key('report_gps_accuracy_circle'),
                          point: LatLng(
                            gpsLocation!.latitude,
                            gpsLocation!.longitude,
                          ),
                          radius: gpsLocation!.accuracy,
                          useRadiusInMeter: true,
                          color: AppColors.info.withValues(alpha: 0.18),
                          borderColor: AppColors.info.withValues(alpha: 0.70),
                          borderStrokeWidth: 2,
                        ),
                        CircleMarker(
                          key: const Key('report_gps_point'),
                          point: LatLng(
                            gpsLocation!.latitude,
                            gpsLocation!.longitude,
                          ),
                          radius: 5,
                          color: AppColors.info,
                          borderColor: AppColors.surface,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (gpsLocation == null)
            Positioned.fill(
              child: ColoredBox(
                color: const Color(0x99EDE9E5),
                child: Center(
                  child: gpsDisabled
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_off_rounded,
                              color: AppColors.brand,
                              size: 34,
                            ),
                            SizedBox(height: 8),
                            LocalizedText(
                              'Allow GPS to show the map',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : const CircularProgressIndicator(color: AppColors.brand),
                ),
              ),
            ),
          if (gpsLocation != null)
            IgnorePointer(
              child: Transform.translate(
                offset: const Offset(0, -20),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.brand,
                  size: 46,
                  shadows: [
                    Shadow(
                      color: Color(0x66000000),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          if (gpsLocation != null)
            Positioned(
              left: 10,
              top: 10,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const LocalizedText(
                    'Drag or tap to choose',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (gpsLocation != null)
            Positioned(
              left: 10,
              bottom: 10,
              child: IgnorePointer(
                child: Container(
                  key: const Key('report_gps_accuracy_label'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '${context.tr('GPS accuracy area')} · ±${gpsLocation!.accuracy.round()} m',
                    style: const TextStyle(
                      color: AppColors.info,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          const Positioned(
            right: 6,
            bottom: 6,
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0xCCFFFFFF),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: LocalizedText(
                    '© OpenStreetMap contributors',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location, required this.selectedFromMap});

  final DeviceLocationData location;
  final bool selectedFromMap;

  @override
  Widget build(BuildContext context) {
    final quality = !selectedFromMap
        ? GpsAccuracyQuality.fromMeters(location.accuracy)
        : null;
    final color = switch (quality) {
      GpsAccuracyQuality.acceptable => AppColors.success,
      GpsAccuracyQuality.okay => AppColors.warning,
      GpsAccuracyQuality.notGood => AppColors.danger,
      null => AppColors.border,
    };
    final background = switch (quality) {
      GpsAccuracyQuality.acceptable => AppColors.successSoft,
      GpsAccuracyQuality.okay => AppColors.warningSoft,
      GpsAccuracyQuality.notGood => AppColors.dangerSoft,
      null => AppColors.surface,
    };

    return Container(
      key: const Key('report_gps_location_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            selectedFromMap
                ? 'Selected Incident Location'
                : 'Current GPS Location',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          LocalizedText(
            '${location.latitude.toStringAsFixed(6)}, '
            '${location.longitude.toStringAsFixed(6)}  ·  '
            '${selectedFromMap ? context.tr('Chosen on map') : '±${location.accuracy.round()} m'}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetectingLocationCard extends StatelessWidget {
  const _DetectingLocationCard({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return _MessageCard(
      title: 'Getting your phone location',
      message: isOffline
          ? 'Searching for GPS satellites. Without cellular signal, this can take up to 90 seconds.'
          : 'This uses the device GPS and may take a few seconds.',
      color: AppColors.infoSoft,
    );
  }
}

class _LocationErrorCard extends StatelessWidget {
  const _LocationErrorCard({required this.problem});

  final DeviceLocationProblem problem;

  @override
  Widget build(BuildContext context) {
    final message = switch (problem) {
      DeviceLocationProblem.serviceDisabled =>
        'Turn on Location Services, then tap Refresh.',
      DeviceLocationProblem.permissionDenied =>
        'Allow location access in the phone prompt, then tap Refresh.',
      DeviceLocationProblem.permissionDeniedForever =>
        'Location access is blocked. Enable it in the phone settings.',
      DeviceLocationProblem.timedOut => 'GPS could not lock on within 90 seconds. Move outdoors with a clear view of the sky, then try again.',
      DeviceLocationProblem.unavailable =>
        'The phone could not provide a location. Please try again.',
    };

    return _MessageCard(
      title: 'Unable to get GPS location',
      message: message,
      color: AppColors.warningSoft,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.title,
    required this.message,
    required this.color,
    this.onTap,
  });

  final String title;
  final String message;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LocalizedText(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              LocalizedText(
                message,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 18 / 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
