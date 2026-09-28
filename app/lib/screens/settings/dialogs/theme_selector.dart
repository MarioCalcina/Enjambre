import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/models/app.dart';
import 'package:provider/provider.dart';

class ThemeSelector extends StatefulWidget {
  const ThemeSelector({super.key});

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  handleChange(ThemeMode? newTheme) {
    if (newTheme == null) return;
    Provider.of<AppModel>(context, listen: false).setTheme(newTheme);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer<AppModel>(builder: (context, app, child) {
      return RadioGroup<ThemeMode>(
        groupValue: app.theme,
        onChanged: handleChange,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            RadioListTile<ThemeMode>(
                title: Text(localizations.system), value: ThemeMode.system),
            RadioListTile<ThemeMode>(
                title: Text(localizations.light), value: ThemeMode.light),
            RadioListTile<ThemeMode>(
                title: Text(localizations.dark), value: ThemeMode.dark),
          ],
        ),
      );
    });
  }
}
