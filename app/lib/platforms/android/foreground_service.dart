import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:enjambre/utils/localizations.dart';
import 'package:enjambre/utils/notifications.dart';

const foregroundNotificationId = 1;

const androidNotificationDetails = AndroidNotificationDetails(
    'foreground_service_channel', 'Foreground Service Channel',
    channelDescription:
        'This channel is used for foreground service notifications.',
    importance: Importance.low,
    silent: true,
    ongoing: true,
    actions: [
      AndroidNotificationAction('exit', 'Exit', showsUserInterface: true)
    ]);

createForegroundService() async {
  // Request runtime notifications permissions
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();

  // The plugin is already initialised by initializeNotifications().

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.stopForegroundService();

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.deleteNotificationChannel('foreground_service_channel');

  final localizations = await appLocalizations();
  await _startOrUpdateForegroundService(localizations.runningInBackground);
}

stopForegroundService() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.stopForegroundService();
}

_startOrUpdateForegroundService(
  String body,
) async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.startForegroundService(foregroundNotificationId, 'Enjambre', body,
          notificationDetails: androidNotificationDetails,
          startType: AndroidServiceStartType.startRedeliverIntent);
}
