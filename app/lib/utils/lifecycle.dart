import 'package:flutter/material.dart';
import 'package:enjambre/models/app.dart';
import 'package:enjambre/models/torrents.dart';
import 'package:enjambre/utils/device.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

void closeApp(BuildContext context) async {
  final appModel = Provider.of<AppModel>(context, listen: false);
  final torrentModel = Provider.of<TorrentsModel>(context, listen: false);
  torrentModel.stopTimer();
  appModel.setQuitting(true);

  if (isDesktop()) {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose) {
      appModel.quitGracefully();
    }
  } else {
    appModel.quitGracefully();
  }
}
