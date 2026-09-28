import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/models/app.dart';
import 'package:provider/provider.dart';

class QuittingDialog extends StatelessWidget {
  const QuittingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.quitting),
      content: Column(mainAxisSize: MainAxisSize.min, spacing: 16, children: [
        Text(localizations.quittingMessage),
        const CircularProgressIndicator()
      ]),
      actions: [
        TextButton(
          child: Text(localizations.forceQuit),
          onPressed: () {
            Provider.of<AppModel>(context, listen: false).quit();
          },
        ),
      ],
    );
  }
}
