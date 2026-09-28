import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/models/app.dart';
import 'package:provider/provider.dart';

import 'package:enjambre/constants/locales.dart';

class LocaleSelector extends StatefulWidget {
  const LocaleSelector({super.key});

  @override
  State<LocaleSelector> createState() => _LocaleSelectorState();
}

class _LocaleSelectorState extends State<LocaleSelector> {
  handleChange(String? locale) {
    if (locale == null) return;
    Provider.of<AppModel>(context, listen: false).setLocale(locale);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(builder: (context, app, child) {
      return RadioGroup<String>(
        groupValue: app.locale,
        onChanged: handleChange,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppLocalizations.supportedLocales
              .map((locale) => RadioListTile<String>(
                    title:
                        Text(localeNames[locale.toString()] ?? locale.toString()),
                    value: locale.toString(),
                  ))
              .toList(),
        ),
      );
    });
  }
}
