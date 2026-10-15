import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

abstract interface class AppLanguageStore {
  Future<String?> readLanguageCode();

  Future<void> writeLanguageCode(String code);

  Future<void> clearLanguageCode();
}

class SharedPreferencesAppLanguageStore implements AppLanguageStore {
  SharedPreferencesAppLanguageStore({SharedPreferencesAsync? client})
    : _preferences = client;

  static const _languageKey = 'selected_app_language';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<String?> readLanguageCode() => _client.getString(_languageKey);

  @override
  Future<void> writeLanguageCode(String code) =>
      _client.setString(_languageKey, code);

  @override
  Future<void> clearLanguageCode() => _client.remove(_languageKey);
}

class AppLanguageController extends ChangeNotifier {
  AppLanguageController({AppLanguageStore? store})
    : _store = store ?? SharedPreferencesAppLanguageStore();

  final AppLanguageStore _store;

  AppLanguage? _selectedLanguage;
  bool _isLoaded = false;

  AppLanguage get language => _selectedLanguage ?? AppLanguage.english;
  bool get hasSelectedLanguage => _selectedLanguage != null;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }

    try {
      final code = await _store.readLanguageCode();
      _selectedLanguage = AppLanguage.fromCode(code);
    } catch (_) {
      _selectedLanguage = null;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> selectLanguage(AppLanguage language) async {
    final changed = _selectedLanguage != language;
    _selectedLanguage = language;
    _isLoaded = true;
    if (changed) {
      notifyListeners();
    }
    await _store.writeLanguageCode(language.code);
  }

  Future<void> resetSelection() async {
    _selectedLanguage = null;
    _isLoaded = true;
    notifyListeners();
    await _store.clearLanguageCode();
  }
}
