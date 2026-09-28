import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';

/// Blocking dialog shown while the player waits for torrent pieces.
class PlayerLoadingDialog extends StatelessWidget {
  final String title;
  final VoidCallback? onCancel;

  const PlayerLoadingDialog({super.key, required this.title, this.onCancel});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(title),
      content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [Center(child: CircularProgressIndicator())]),
      actions: onCancel == null
          ? null
          : [
              TextButton(
                onPressed: onCancel,
                child: Text(localizations.cancel),
              ),
            ],
    );
  }
}
