import 'dart:async';

import 'package:geolocator/geolocator.dart';

enum DeviceLocationProblem {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  timedOut,
  unavailable,
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.problem);

  final DeviceLocationProblem problem;
}

class DeviceLocationData {
  const DeviceLocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;
}

class DeviceLocationService {
  const DeviceLocationService();

  /// Normal assisted location lookup when network-based location aids exist.
  static const assistedFixTimeout = Duration(seconds: 30);

  /// A cold satellite-only fix can take substantially longer without a
  /// cellular or Wi-Fi connection, including while Airplane Mode is enabled.
  static const satelliteFixTimeout = Duration(seconds: 90);

  Future<bool> hasWhenInUsePermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestWhenInUsePermission() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (_) {
      return false;
    }
  }

  Future<DeviceLocationData> getCurrentLocation({
    bool requestPermission = false,
    Duration timeLimit = assistedFixTimeout,
  }) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const DeviceLocationException(
          DeviceLocationProblem.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        throw const DeviceLocationException(
          DeviceLocationProblem.permissionDeniedForever,
        );
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        throw const DeviceLocationException(
          DeviceLocationProblem.permissionDenied,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: timeLimit,
        ),
      );

      return DeviceLocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
    } on DeviceLocationException {
      rethrow;
    } on TimeoutException {
      throw const DeviceLocationException(DeviceLocationProblem.timedOut);
    } catch (_) {
      throw const DeviceLocationException(DeviceLocationProblem.unavailable);
    }
  }

  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}
