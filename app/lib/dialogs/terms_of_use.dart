import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:flutter/services.dart';
import 'package:enjambre/models/app.dart';
import 'package:provider/provider.dart';

class TermsOfUseDialog extends StatelessWidget {
  const TermsOfUseDialog({super.key});

  _handleRefuseClick() {
    SystemNavigator.pop();
  }

  _handleAcceptClick(context) {
    Provider.of<AppModel>(context, listen: false).setTermsOfUseAccepted(true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(localizations.termsOfUseTitle),
      content: Text(localizations.termsOfUseContent),
      actions: [
        TextButton(
          onPressed: _handleRefuseClick,
          child: Text(localizations.refuse),
        ),
        TextButton(
          onPressed: () => _handleAcceptClick(context),
          child: Text(localizations.accept),
        ),
      ],
    );
  }
}
