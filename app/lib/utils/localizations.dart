import 'package:flutter/widgets.dart';

import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/storage/shared_preferences.dart';

/// Key the selected language is stored under.
const localeKey = 'locale';

/// Language used until the user picks another one.
const defaultLocaleName = 'es';

/// Builds the locale a stored language name stands for, e.g. 'es' or
/// 'zh_Hant', the way [Locale.toString] writes it.
///
/// A four letter subtag is a script, not a country: 'zh_Hant' is Traditional
/// Chinese, and Locale('zh', 'Hant') would resolve to Simplified Chinese.
Locale parseLocaleName(String name) {
  final parts = name.split('_');
  if (parts.first.isEmpty) return const Locale(defaultLocaleName);

  String? scriptCode;
  String? countryCode;
  for (final subtag in parts.skip(1)) {
    if (subtag.length == 4) {
      scriptCode = subtag;
    } else {
      countryCode = subtag;
    }
  }

  return Locale.fromSubtags(
      languageCode: parts.first,
      scriptCode: scriptCode,
      countryCode: countryCode);
}

/// Resolves the app messages outside of the widget tree.
///
/// Notifications are built from the models and from the foreground service,
/// where there is no BuildContext to read the localizations from. Without
/// this they end up hardcoded in English, whatever language the app is set to.
Future<AppLocalizations> appLocalizations() async {
  final name =
      await SharedPrefsStorage.getString(localeKey) ?? defaultLocaleName;

  final locale = parseLocaleName(name);

  // A language that was dropped from the translations must not throw.
  if (!AppLocalizations.delegate.isSupported(locale)) {
    return lookupAppLocalizations(const Locale(defaultLocaleName));
  }

  return lookupAppLocalizations(locale);
}
