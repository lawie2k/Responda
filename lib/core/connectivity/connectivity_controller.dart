import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

abstract interface class ConnectivityReader {
  Future<List<ConnectivityResult>> checkConnectivity();

  Stream<List<ConnectivityResult>> get onConnectivityChanged;
}

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
  ConnectivityController({ConnectivityReader? reader})
    : _reader = reader ?? DeviceConnectivityReader();

  final ConnectivityReader _reader;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool? _isOnline;
  bool? get isOnline => _isOnline;
  bool get isOffline => _isOnline == false;
  bool get hasStatus => _isOnline != null;

  Future<void> initialize() async {
    _subscription ??= _reader.onConnectivityChanged.listen(
      _applyResults,
      onError: (_) {},
    );
    await refresh();
  }

  Future<void> refresh() async {
    try {
      _applyResults(await _reader.checkConnectivity());
    } catch (_) {
      if (_isOnline == null) {
        _setOnline(false);
      }
    }
  }

  void _applyResults(List<ConnectivityResult> results) {
    _setOnline(results.hasConnectivity);
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
