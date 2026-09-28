import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:enjambre/utils/device.dart';
import 'package:enjambre/utils/lifecycle.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

initTray(BuildContext context) async {
  if (!isDesktop()) return;

  try {
    final listener = AppTrayListener(context: context);
    trayManager.addListener(listener);

    if (Platform.isWindows) {
      await trayManager.setIcon('assets/tray_icon.ico');
    } else if (isFlatpak()) {
      await trayManager.setIcon(
          Platform.environment['FLATPAK_ID'] ?? 'assets/tray_icon.png');
    } else {
      await trayManager.setIcon('assets/tray_icon.png');
    }

    if (Platform.isWindows || Platform.isMacOS) {
      await trayManager.setToolTip('Enjambre');
    }

    Menu menu = Menu(
      items: [
        MenuItem(
          key: 'show_window',
          label: 'Show Window',
        ),
        MenuItem.separator(),
        MenuItem(
          key: 'exit_app',
          label: 'Exit App',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
  } catch (e) {
    debugPrint(e.toString());
  }
}

closeTray() async {
  if (!isDesktop()) return;
  await trayManager.destroy();
}

class AppTrayListener extends TrayListener {
  final BuildContext context;

  AppTrayListener({required this.context});

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    debugPrint('onTrayMenuItemClick ${menuItem.key}');
    if (menuItem.key == 'show_window') {
      windowManager.show();
      windowManager.focus();
    } else if (menuItem.key == 'exit_app') {
      windowManager.show();
      windowManager.focus();
      closeApp(context);
    }
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // bringAppToFront should be set until
    // https://github.com/leanflutter/tray_manager/issues/63 is resolved
    // ignore: deprecated_member_use
    trayManager.popUpContextMenu(bringAppToFront: true);
  }
}
