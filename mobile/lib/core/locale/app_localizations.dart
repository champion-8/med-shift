import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'strings_en.dart';
import 'strings_th.dart';

class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('th'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  String tr(String key) {
    return (_map[locale.languageCode] ?? stringsTh)[key] ?? key;
  }

  /// Replace `{name}` style placeholders in a translated string.
  String trParams(String key, Map<String, String> params) {
    var value = tr(key);
    params.forEach((k, v) {
      value = value.replaceAll('{$k}', v);
    });
    return value;
  }

  bool get isThai => locale.languageCode == 'th';

  static const Map<String, Map<String, String>> _map = {
    'th': stringsTh,
    'en': stringsEn,
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['th', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(AppLocalizations(locale));

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience extension – use `context.tr('key')` in any widget
extension AppLocalizationsExt on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String tr(String key) => AppLocalizations.of(this).tr(key);
  String trParams(String key, Map<String, String> params) =>
      AppLocalizations.of(this).trParams(key, params);
}
