import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:enjambre/dialogs/add_torrent.dart';
import 'package:enjambre/dialogs/confirm_exit.dart';
import 'package:enjambre/dialogs/quitting.dart';
import 'package:enjambre/dialogs/terms_of_use.dart';
import 'package:enjambre/models/app.dart';
import 'package:enjambre/navigation/navigation.dart';
import 'package:enjambre/platforms/desktop/tray.dart';
import 'package:enjambre/utils/connectivity.dart';
import 'package:enjambre/utils/device.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class AppShellRoute extends StatefulWidget {
  final Widget child;

  const AppShellRoute({super.key, required this.child});

  @override
  State<AppShellRoute> createState() => _AppShellRouteState();
}

class _AppShellRouteState extends State<AppShellRoute> with WindowListener {
  late AppLinks _appLinks;
  bool isTermsOfUseDialogDisplayed = false;
  bool showQuittingDialog = false;

  @override
  void initState() {
    super.initState();
    startConnectivityCheck(context);
    initTray(context);
    _initAppLinks();
    windowManager.addListener(this);
    _initWindowManager();
  }

  @override
  void dispose() {
    stopConnectivityCheck();
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Workaround to detect if current route is the player, and pop it
    Navigator.of(context).popUntil((route) {
      final currentRouteName = route.settings.name;
      if (currentRouteName == 'player') {
        // Remove route immediately to avoid concurrency issue,
        // where player could still run while window is hidden
        Navigator.removeRoute(context, route);
      }

      return true;
    });

    windowManager.hide();
  }

  _initWindowManager() async {
    if (isDesktop()) {
      // Add this line to override the default close handler
      await windowManager.setPreventClose(true);
      setState(() {});
    }
  }

  _initAppLinks() {
    _appLinks = AppLinks();
    _appLinks.uriLinkStream.listen((uri) async {
      var uriString = uri.toString();

      if (uri.scheme == 'magnet') {
        // Magnet link
        _openAddTorrentDialog(uriString, null);
      } else if (uri.scheme == 'content') {
        _openAddTorrentDialog(null, uriString);
      } else if (uri.scheme == 'file') {
        _openAddTorrentDialog(null, uri.toFilePath());
      } else if (File(uriString).existsSync()) {
        // Filesystem path
        _openAddTorrentDialog(null, uriString);
      }
    });
  }

  _openAddTorrentDialog(String? initialMagnetLink, String? initialContentPath) {
    if (Navigator.canPop(context)) {
      // Pop current dialog, if any
      Navigator.pop(context);
    }

    showDialog(
        context: context,
        builder: (BuildContext context) {
          return AddTorrentDialog(
            initialMagnetLink: initialMagnetLink,
            initialContentPath: initialContentPath,
          );
        });

    if (isTermsOfUseDialogDisplayed) {
      // FIXME
      // This will re-trigger the terms of use dialog, if needed.
      // This dialog should be displayed above.
      setState(() {
        isTermsOfUseDialogDisplayed = false;
      });
    }
  }

  _openTermsOfUseDialog(AppModel appModel) {
    var termsOfUseAccepted = appModel.termsOfUseAccepted;

    if (!isTermsOfUseDialogDisplayed && !termsOfUseAccepted) {
      // Avoid calling the dialog multiple times
      isTermsOfUseDialogDisplayed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const TermsOfUseDialog();
            });
      });
    }
  }

  _openQuittingDialog(AppModel appModel) {
    if (!showQuittingDialog) {
      showQuittingDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const QuittingDialog();
            });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModel>(builder: (context, appModel, child) {
      if (appModel.loaded) {
        _openTermsOfUseDialog(appModel);
      }

      if (appModel.quitting && !showQuittingDialog) {
        _openQuittingDialog(appModel);
      }

      return PopScope(
          canPop: false,
          onPopInvokedWithResult: (a, b) => _onWillPopApp(context),
          child: Navigation(child: widget.child));
    });
  }
}

Future<bool> _onWillPopApp(BuildContext context) async {
  return await showDialog(
    context: context,
    builder: (context) => const ConfirmExit(),
  );
}
