import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract interface class ConnectivityReader {
  Future<List<ConnectivityResult>> checkConnectivity();

  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

typedef BackendAvailabilityCheck = Future<bool> Function();

class DeviceConnectivityReader implements ConnectivityReader {
  DeviceConnectivityReader({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() =>
      _connectivity.checkConnectivity();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _connectivity.onConnectivityChanged;
}

class ConnectivityController extends ChangeNotifier {
  ConnectivityController({
    ConnectivityReader? reader,
    this.backendAvailabilityCheck,
  }) : _reader = reader ?? DeviceConnectivityReader();

  final ConnectivityReader _reader;
  final BackendAvailabilityCheck? backendAvailabilityCheck;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  int _checkGeneration = 0;

  bool? _isOnline;
  bool? get isOnline => _isOnline;
  bool get isOffline => _isOnline == false;
  bool get hasStatus => _isOnline != null;

  Future<void> initialize() async {
    _subscription ??= _reader.onConnectivityChanged.listen(
      (results) => unawaited(_applyResults(results)),
      onError: (_) {},
    );
    await refresh();
  }

  Future<void> refresh() async {
    List<ConnectivityResult> results;
    try {
      results = await _reader.checkConnectivity();
    } catch (_) {
      results = [ConnectivityResult.none];
    }
    await _applyResults(results);
  }

  Future<void> _applyResults(List<ConnectivityResult> results) async {
    final generation = ++_checkGeneration;
    final backendCheck = backendAvailabilityCheck;
    if (backendCheck == null) {
      _setOnline(results.hasConnectivity);
      return;
    }

    // iOS may report no internet path while the local USB backend is reachable.
    // The actual health request is authoritative when a backend is configured.
    try {
      final backendAvailable = await backendCheck();
      if (generation == _checkGeneration) {
        _setOnline(backendAvailable);
      }
    } catch (_) {
      if (generation == _checkGeneration) {
        _setOnline(false);
      }
    }
  }

  void _setOnline(bool value) {
    if (_isOnline == value) {
      return;
    }
    _isOnline = value;
    debugPrint('RESPONDA connection mode: ${value ? 'online' : 'offline'}');
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
