import 'package:flutter/widgets.dart';

import '../../features/localization/data/bisaya_translations.dart';
import '../../features/localization/data/tagalog_translations.dart';
import 'app_language.dart';
import 'app_language_scope.dart';

class AppStrings {
  const AppStrings(this.language);

  final AppLanguage language;

  String text(String english, {Map<String, Object?> values = const {}}) {
    final translations = switch (language) {
      AppLanguage.english => const <String, String>{},
      AppLanguage.filipino => tagalogTranslations,
      AppLanguage.cebuano => bisayaTranslations,
    };
    var result = translations[english] ?? english;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', '${entry.value ?? ''}');
    }
    return result;
  }
}

extension AppStringsBuildContext on BuildContext {
  AppStrings get strings => AppStrings(
    AppLanguageScope.maybeOf(this)?.language ?? AppLanguage.english,
  );

  String tr(String english, {Map<String, Object?> values = const {}}) =>
      strings.text(english, values: values);
}
