import 'package:flutter/foundation.dart';

import '../data/home_tutorial_store.dart';

class HomeTutorialController extends ChangeNotifier {
  HomeTutorialController({HomeTutorialProgressStore? store})
    : _store = store ?? const SharedPreferencesHomeTutorialStore();

  static const totalSteps = 4;

  final HomeTutorialProgressStore _store;
  bool _loaded = false;
  bool _visible = false;
  int _step = 0;

  bool get visible => _visible;
  int get step => _step;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final completed = await _store.readCompleted();
    _visible = !completed;
    notifyListeners();
  }

  Future<void> next() async {
    if (_step < totalSteps - 1) {
      _step++;
      notifyListeners();
      return;
    }
    await complete();
  }

  Future<void> complete() async {
    _visible = false;
    notifyListeners();
    await _store.writeCompleted(true);
  }
}
