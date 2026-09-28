import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class AppSettingsStore {
  Future<bool?> readNotificationsEnabled();

  Future<void> writeNotificationsEnabled(bool value);
}

class SharedPreferencesAppSettingsStore implements AppSettingsStore {
  SharedPreferencesAppSettingsStore({SharedPreferencesAsync? client})
    : _preferences = client;

  static const _notificationsKey = 'notifications_enabled';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<bool?> readNotificationsEnabled() =>
      _client.getBool(_notificationsKey);

  @override
  Future<void> writeNotificationsEnabled(bool value) =>
      _client.setBool(_notificationsKey, value);
}

class AppSettingsController extends ChangeNotifier {
  AppSettingsController({AppSettingsStore? store})
    : _store = store ?? SharedPreferencesAppSettingsStore();

  final AppSettingsStore _store;

  bool _notificationsEnabled = true;
  bool _isLoaded = false;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      _notificationsEnabled = await _store.readNotificationsEnabled() ?? true;
    } catch (_) {
      _notificationsEnabled = true;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final changed = _notificationsEnabled != value;
    _notificationsEnabled = value;
    _isLoaded = true;
    if (changed) {
      notifyListeners();
    }
    await _store.writeNotificationsEnabled(value);
  }
}
