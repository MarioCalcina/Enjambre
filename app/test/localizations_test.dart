import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/l10n/app_localizations_zh.dart';
import 'package:enjambre/utils/localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseLocaleName', () {
    test('reads back every locale the language selector stores', () {
      // The selector stores Locale.toString() of the supported locales.
      for (final locale in AppLocalizations.supportedLocales) {
        expect(parseLocaleName(locale.toString()), locale);
      }
    });

    test('Traditional Chinese is a script, not a country', () {
      final locale = parseLocaleName('zh_Hant');

      expect(locale.scriptCode, 'Hant');
      expect(locale.countryCode, isNull);
      expect(lookupAppLocalizations(locale), isA<AppLocalizationsZhHant>());
    });

    test('the app resolves Traditional Chinese to itself', () {
      // What MaterialApp does with the locale it is given.
      final resolved = basicLocaleListResolution(
          [parseLocaleName('zh_Hant')], AppLocalizations.supportedLocales);

      expect(resolved.scriptCode, 'Hant');
    });

    test('a two letter subtag is a country', () {
      final locale = parseLocaleName('pt_BR');

      expect(locale.languageCode, 'pt');
      expect(locale.countryCode, 'BR');
      expect(locale.scriptCode, isNull);
    });

    test('an empty name falls back to the default language', () {
      expect(parseLocaleName(''), const Locale(defaultLocaleName));
    });
  });
}
