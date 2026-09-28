import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class TestingModeStore {
  Future<bool?> readOutsidePantukan();

  Future<void> writeOutsidePantukan(bool value);
}

class SharedPreferencesTestingModeStore implements TestingModeStore {
  SharedPreferencesTestingModeStore({SharedPreferencesAsync? client})
    : _preferences = client;

  static const _outsidePantukanKey = 'testing_outside_pantukan';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<bool?> readOutsidePantukan() => _client.getBool(_outsidePantukanKey);

  @override
  Future<void> writeOutsidePantukan(bool value) =>
      _client.setBool(_outsidePantukanKey, value);
}

class TestingModeController extends ChangeNotifier {
  TestingModeController({TestingModeStore? store})
    : _store = store ?? SharedPreferencesTestingModeStore();

  final TestingModeStore _store;

  bool _outsidePantukan = false;
  bool _isLoaded = false;

  bool get outsidePantukan => _outsidePantukan;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      _outsidePantukan = await _store.readOutsidePantukan() ?? false;
    } catch (_) {
      _outsidePantukan = false;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setOutsidePantukan(bool value) async {
    final changed = _outsidePantukan != value;
    _outsidePantukan = value;
    _isLoaded = true;
    if (changed) notifyListeners();
    await _store.writeOutsidePantukan(value);
  }

  Future<void> reset() => setOutsidePantukan(false);
}
