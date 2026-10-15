import 'package:shared_preferences/shared_preferences.dart';

abstract interface class HomeTutorialProgressStore {
  Future<bool> readCompleted();

  Future<void> writeCompleted(bool value);

  Future<void> reset();
}

class SharedPreferencesHomeTutorialStore implements HomeTutorialProgressStore {
  const SharedPreferencesHomeTutorialStore([this._preferences]);

  static const _completedKey = 'home_tutorial_completed_v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _client async =>
      _preferences ?? await SharedPreferences.getInstance();

  @override
  Future<bool> readCompleted() async =>
      (await _client).getBool(_completedKey) ?? false;

  @override
  Future<void> writeCompleted(bool value) async {
    await (await _client).setBool(_completedKey, value);
  }

  @override
  Future<void> reset() async {
    await (await _client).remove(_completedKey);
  }
}
