import 'package:flutter/widgets.dart';

enum AppLanguage {
  english(code: 'en', displayName: 'English'),
  filipino(code: 'fil', displayName: 'Filipino/Tagalog'),
  cebuano(code: 'ceb', displayName: 'Bisaya/Cebuano');

  const AppLanguage({required this.code, required this.displayName});

  final String code;
  final String displayName;

  Locale get locale => Locale(code);

  Locale get frameworkLocale => switch (this) {
    AppLanguage.english => const Locale('en'),
    AppLanguage.filipino => const Locale('fil'),
    AppLanguage.cebuano => const Locale('en'),
  };

  static AppLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }
}
