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
    try {
      await _applyResults(await _reader.checkConnectivity());
    } catch (_) {
      if (_isOnline == null) {
        _setOnline(false);
      }
    }
  }

  Future<void> _applyResults(List<ConnectivityResult> results) async {
    final generation = ++_checkGeneration;
    if (!results.hasConnectivity) {
      _setOnline(false);
      return;
    }

    final backendCheck = backendAvailabilityCheck;
    if (backendCheck == null) {
      _setOnline(true);
      return;
    }

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
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
