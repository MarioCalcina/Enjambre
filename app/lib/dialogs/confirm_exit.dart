import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/utils/lifecycle.dart';

class ConfirmExit extends StatelessWidget {
  const ConfirmExit({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.confirmExitTitle),
      content: Text(localizations.confirmExitContent),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(localizations.no),
        ),
        TextButton(
          onPressed: () {
            closeApp(context);
          },
          child: Text(localizations.yes),
        ),
      ],
    );
  }
}
