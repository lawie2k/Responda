import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class GpsPreferenceStore {
  Future<bool?> readAllowGps();

  Future<void> writeAllowGps(bool value);
}

class SharedPreferencesGpsPreferenceStore implements GpsPreferenceStore {
  SharedPreferencesGpsPreferenceStore({SharedPreferencesAsync? client})
    : _preferences = client;

  static const _allowGpsKey = 'allow_phone_gps';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<bool?> readAllowGps() => _client.getBool(_allowGpsKey);

  @override
  Future<void> writeAllowGps(bool value) =>
      _client.setBool(_allowGpsKey, value);
}

class GpsPreferenceController extends ChangeNotifier {
  GpsPreferenceController({GpsPreferenceStore? store})
    : _store = store ?? SharedPreferencesGpsPreferenceStore();

  final GpsPreferenceStore _store;

  bool _allowGps = true;
  bool _isLoaded = false;

  bool get allowGps => _allowGps;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      _allowGps = await _store.readAllowGps() ?? true;
    } catch (_) {
      _allowGps = true;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setAllowGps(bool value) async {
    final changed = _allowGps != value;
    _allowGps = value;
    _isLoaded = true;
    if (changed) {
      notifyListeners();
    }
    await _store.writeAllowGps(value);
  }
}
