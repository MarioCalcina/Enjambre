import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:enjambre/l10n/app_localizations.dart';
import 'package:enjambre/utils/device.dart';
import 'package:share_plus/share_plus.dart';

shareLink(BuildContext context, String magnetLink) async {
  if (isMobile()) {
    await Share.share(magnetLink);
  } else {
    Clipboard.setData(ClipboardData(text: magnetLink));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(AppLocalizations.of(context)!.linkCopied),
      backgroundColor: Colors.lightGreen,
    ));
  }
}
