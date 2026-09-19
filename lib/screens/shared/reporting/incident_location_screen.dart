import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:responda/core/location/device_location_service.dart';
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
    this.returnToReview = false,
    super.key,
  });

  final ReportDraft draft;
  final ReportFlowMode flowMode;
  final ReportLocationLoader? loadLocation;
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
  GpsPreferenceController? _gpsPreferenceController;

  @override
  void initState() {
    super.initState();
    _landmarkController.text = widget.draft.landmark;
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
            message: 'RESPONDA will save the coordinates from your phone. No online map is needed.',
            color: AppColors.warningSoft,
          ),
        _LocationTag(
          isLoading: _isLoading,
          hasLocation: location != null,
          gpsDisabled: _gpsDisabled,
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
          const _MessageCard(
            title: 'Allow GPS',
            message:
                'Turn on Allow GPS to use your phone location for this report.',
            color: AppColors.warningSoft,
          )
        else if (location != null)
          _LocationCard(location: location, selectedFromMap: _selectionMoved)
        else if (_problem != null)
          _LocationErrorCard(problem: _problem!)
        else
          const _DetectingLocationCard(),
        Row(
          children: [
            Expanded(
              child: RespondaButton(
                label: _gpsDisabled
                    ? 'Allow GPS'
                    : _isLoading
                    ? 'Refreshing…'
                    : 'Refresh',
                style: RespondaButtonStyle.ghost,
                onPressed: _isLoading
                    ? null
                    : _gpsDisabled
                    ? _enableGps
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
        if (!widget.flowMode.isOffline) ...[
          TextField(
            controller: _landmarkController,
            focusNode: _landmarkFocus,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Landmark',
              hintText: 'e.g. Kingking Highway',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
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
            label: 'Enter Landmark Manually',
            style: RespondaButtonStyle.secondary,
            onPressed: () => _landmarkFocus.requestFocus(),
          ),
        ],
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
          () => _locationService.getCurrentLocation(requestPermission: true);
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

  Future<void> _enableGps() async {
    final permissionGranted = await _locationService
        .requestWhenInUsePermission();
    if (!mounted || !permissionGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission was not allowed in your phone settings.',
            ),
          ),
        );
      }
      return;
    }

    final controller = _gpsPreferenceController;
    if (controller == null) {
      setState(() => _gpsDisabled = false);
      await _refreshLocation();
    } else {
      _autoLocationAttempted = false;
      await controller.setAllowGps(true);
    }
  }

  bool get _isGpsAllowed => _gpsPreferenceController?.allowGps ?? true;

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
    _mapController.move(LatLng(location.latitude, location.longitude), 17);
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
  });

  final bool isLoading;
  final bool hasLocation;
  final bool gpsDisabled;

  @override
  Widget build(BuildContext context) {
    final label = gpsDisabled
        ? 'Allow GPS'
        : isLoading
        ? 'Detecting location'
        : hasLocation
        ? 'Location detected'
        : 'Location unavailable';
    final color = hasLocation ? AppColors.success : AppColors.warning;
    final background = hasLocation
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
            Text(
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
                          point: LatLng(
                            gpsLocation!.latitude,
                            gpsLocation!.longitude,
                          ),
                          radius: 7,
                          color: AppColors.info,
                          borderColor: AppColors.surface,
                          borderStrokeWidth: 3,
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
                            Text(
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
                  child: const Text(
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
          const Positioned(
            right: 6,
            bottom: 6,
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0xCCFFFFFF),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
          Text(
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
          Text(
            '${location.latitude.toStringAsFixed(6)}, '
            '${location.longitude.toStringAsFixed(6)}  ·  '
            '${selectedFromMap ? 'Chosen on map' : '±${location.accuracy.round()} m'}',
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
  const _DetectingLocationCard();

  @override
  Widget build(BuildContext context) {
    return const _MessageCard(
      title: 'Getting your phone location',
      message: 'This uses the device GPS and may take a few seconds.',
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
      DeviceLocationProblem.timedOut =>
        'The GPS request timed out. Move to an open area and try again.',
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
    required this.title,
    required this.message,
    required this.color,
  });

  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
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
