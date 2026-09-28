import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:enjambre/navigation/router.dart';
import 'package:enjambre/utils/device.dart';

enum NotificationsDetailsTypes { downloadsCompletedAndroidNotificationDetails }

const downloadsCompletedAndroidNotificationDetails = AndroidNotificationDetails(
    'downloads_completed', 'Downloads completed',
    channelDescription:
        'This channel is used for downloads completed notifications.');

/// The one plugin instance of the app.
///
/// It is shared with the foreground service: two instances each calling
/// initialize() with their own settings means the last one wins, silently
/// dropping the settings and the tap handler of the other.
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void _onDidReceiveNotificationResponse(
    NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'exit') {
    rootNavigatorKey.currentState?.maybePop();
  }
}

_removeNotificationChannels() async {
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.deleteNotificationChannel('downloads_completed');
}

Future<void> initializeNotifications() async {
  await _removeNotificationChannels();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_stat_name');

  final List<DarwinNotificationCategory> darwinNotificationCategories =
      <DarwinNotificationCategory>[];

  final DarwinInitializationSettings initializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: false,
    requestSoundPermission: false,
    notificationCategories: darwinNotificationCategories,
  );

  final LinuxInitializationSettings initializationSettingsLinux =
      LinuxInitializationSettings(
    defaultActionName: 'Open notification',
    // TODO: Improve icon
    defaultIcon: isFlatpak()
        ? ThemeLinuxIcon('com.enjambre.Enjambre')
        : AssetsLinuxIcon('assets/tray_icon.png'),
  );

  final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
      linux: initializationSettingsLinux,
      windows: const WindowsInitializationSettings(
          appName: 'Enjambre',
          appUserModelId: 'com.enjambre.Enjambre',
          // Todo: icon path, see https://github.com/MaikuB/flutter_local_notifications/issues/2605
          // iconPath: 'assets/tray_icon.ico',
          guid: 'ee954ddd-68ec-4e8f-8482-3e84413532da'));

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    // Handles the Exit action of the foreground service notification.
    onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
  );
}

/// Ids below this one are left to the notifications of the app itself, such
/// as the foreground service one.
const _firstTorrentNotificationId = 1000;

/// Id of the notifications about a torrent. Each torrent has its own, so that
/// two downloads completing together do not replace each other.
int torrentNotificationId(int torrentId) =>
    _firstTorrentNotificationId + torrentId;

showNotification(
    {required int id,
    required String title,
    required String body,
    NotificationsDetailsTypes? notificationsDetailsType}) async {
  final androidNotificationDetails = switch (notificationsDetailsType) {
    NotificationsDetailsTypes.downloadsCompletedAndroidNotificationDetails =>
      downloadsCompletedAndroidNotificationDetails,
    _ => null
  };

  final NotificationDetails notificationDetails =
      NotificationDetails(android: androidNotificationDetails);

  flutterLocalNotificationsPlugin.show(id, title, body, notificationDetails,
      payload: null);
}
