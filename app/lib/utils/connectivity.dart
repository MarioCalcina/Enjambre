import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:enjambre/l10n/app_localizations.dart';

late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;

// listen to network changes
startConnectivityCheck(BuildContext context) {
  ScaffoldFeatureController? snackBar;

  _connectivitySubscription = Connectivity()
      .onConnectivityChanged
      .listen((List<ConnectivityResult> result) {
    if (!context.mounted) return;

    if (result.contains(ConnectivityResult.none)) {
      snackBar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        showCloseIcon: true,
        content: Text(AppLocalizations.of(context)!.networkUnavailable),
        backgroundColor: Colors.orange,
        duration: const Duration(days: 365), // Ideally, unlimited duration
      ));
    } else {
      // Close previous snackbar
      if (snackBar != null) {
        snackBar?.close();
        snackBar = ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.backOnline),
          backgroundColor: Colors.lightGreen,
        ));
      }
    }
  });
}

stopConnectivityCheck() {
  _connectivitySubscription.cancel();
}
