import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';

class StoragePermissionDialog extends StatelessWidget {
  final bool isPermanentlyDenied;

  const StoragePermissionDialog(
      {super.key, required this.isPermanentlyDenied});

  _requestPermission(BuildContext context) {
    if (isPermanentlyDenied) {
      openAppSettings();
    } else {
      Permission.storage.request();
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return AlertDialog(
      content: Text(localizations.storagePermissionMessage),
      actions: [
        TextButton(
          onPressed: () => _requestPermission(context),
          child: Text(isPermanentlyDenied
              ? localizations.openSettings
              : localizations.continueLabel),
        ),
      ],
    );
  }
}
