import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:enjambre/constants/locales.dart';
import 'package:enjambre/dialogs/reusable/number_input.dart';
import 'package:enjambre/engine/session.dart';
import 'package:enjambre/main.dart';
import 'package:enjambre/models/app.dart';
import 'package:enjambre/models/session.dart';
import 'package:enjambre/screens/settings/dialogs/locale_selector.dart';
import 'package:enjambre/screens/settings/dialogs/reset_torrent_settings.dart';
import 'package:enjambre/screens/settings/dialogs/theme_selector.dart';
import 'package:enjambre/platforms/android/default_session.dart'
    as android_storage;
import 'package:enjambre/storage/shared_preferences.dart';
import 'package:enjambre/utils/storage.dart';
import 'package:enjambre/utils/string_extensions.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:enjambre/l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool showAdvancedSettings = false;
  bool hasFullStorageAccess = false;

  @override
  void initState() {
    super.initState();
    _loadStorageAccess();
  }

  Future<void> _loadStorageAccess() async {
    if (!Platform.isAndroid) return;

    final granted = await android_storage.hasFullStorageAccess();
    if (mounted) {
      setState(() {
        hasFullStorageAccess = granted;
      });
    }
  }

  // Handlers
  void handlePickFolder(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final sessionModel = Provider.of<SessionModel>(context, listen: false);

    final selectedDirectory = await FilePicker.platform
        .getDirectoryPath(dialogTitle: localizations.downloadDirectoryPicker);

    if (selectedDirectory == null) return;

    // Being allowed to browse a folder is not being allowed to write in it:
    // on Android the system hands over a browsing permission, not the plain
    // file access transmission works with.
    if (!await isDirectoryWritable(selectedDirectory)) {
      messenger.showSnackBar(SnackBar(
        content: Text(localizations.downloadDirectoryNotWritable),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    await sessionModel.session
        ?.update(SessionBase(downloadDir: selectedDirectory));
    await SharedPrefsStorage.setBool(
        android_storage.downloadDirPickedByUserKey, true);
    await sessionModel.fetchSession();
  }

  void handleRequestStorageAccess(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final sessionModel = Provider.of<SessionModel>(context, listen: false);

    final status = await (await android_storage.storagePermission()).request();

    if (mounted) {
      setState(() {
        hasFullStorageAccess = status.isGranted;
      });
    }

    if (!status.isGranted) {
      messenger.showSnackBar(SnackBar(
        content: Text(localizations.allFilesAccessDenied),
        backgroundColor: Colors.orange,
      ));
      return;
    }

    // The shared folder is usable now, so the downloads move back to it.
    final publicDir = await android_storage.publicDownloadDir();
    if (publicDir == null || !await isDirectoryWritable(publicDir)) return;

    await sessionModel.session?.update(SessionBase(downloadDir: publicDir));
    await SharedPrefsStorage.setBool(
        android_storage.downloadDirPickedByUserKey, false);
    await sessionModel.fetchSession();

    messenger.showSnackBar(SnackBar(
      content: Text(localizations.downloadDirectoryUpdated),
      backgroundColor: Colors.lightGreen,
    ));
  }

  void handleMaximumActiveDownloadsSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(downloadQueueSize: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handlePeerPortSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(peerPort: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handleSpeedLimitDownSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(speedLimitDown: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handleSpeedLimitUpSave(BuildContext context, int value) async {
    var sessionUpdate = SessionBase(speedLimitUp: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  void handleResetTorrentsSettings(BuildContext context) async {
    await engine.resetSettings();
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.fetchSession();
    }
  }

  void _handleEnableSpeedLimits(bool value) async {
    var sessionUpdate =
        SessionBase(speedLimitDownEnabled: value, speedLimitUpEnabled: value);
    if (context.mounted) {
      var sessionModel = Provider.of<SessionModel>(context, listen: false);
      await sessionModel.session?.update(sessionUpdate);
      await sessionModel.fetchSession();
    }
  }

  // Dialogs
  void showThemeDialog(context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(localizations.theme),
          content: const ThemeSelector(),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showLocaleDialog(context) {
    final localizations = AppLocalizations.of(context)!;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.language),
          content: const LocaleSelector(),
          actions: <Widget>[
            TextButton(
              child: Text(localizations.cancel),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void showMaximumActiveDownloadDialog() {
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title: AppLocalizations.of(context)!.maximumActiveDownloads,
          currentValue: session?.downloadQueueSize ?? 0,
          onSave: (value) => handleMaximumActiveDownloadsSave(context, value),
        );
      },
    );
  }

  void showPeerPortDialog() {
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title: AppLocalizations.of(context)!.incomingPort,
          currentValue: session?.peerPort ?? 0,
          min: 1,
          max: 65535,
          onSave: (value) => handlePeerPortSave(context, value),
        );
      },
    );
  }

  void showSpeedLimitDownDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title:
              '${localizations.downloadSpeed} ${localizations.kilobytesPerSecond}',
          currentValue: session?.speedLimitDown ?? 0,
          onSave: (value) => handleSpeedLimitDownSave(context, value),
        );
      },
    );
  }

  void showSpeedLimitUpDialog() {
    final localizations = AppLocalizations.of(context)!;
    final session = Provider.of<SessionModel>(context, listen: false).session;
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return NumberInputDialog(
          title:
              '${localizations.uploadSpeed} ${localizations.kilobytesPerSecond}',
          currentValue: session?.speedLimitUp ?? 0,
          onSave: (value) => handleSpeedLimitUpSave(context, value),
        );
      },
    );
  }

  void showResetTorrentsSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return ResetTorrentsSettingsDialog(
          onOK: () => handleResetTorrentsSettings(context),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Consumer2<AppModel, SessionModel>(
        builder: (context, app, sessionModel, child) {
      final downloadDir = sessionModel.session?.downloadDir ?? '';
      final downloadQueueSize = sessionModel.session?.downloadQueueSize ?? '';
      final peerPort = sessionModel.session?.peerPort ?? '';
      final isSpeedLimitEnabled =
          sessionModel.session?.speedLimitDownEnabled == true ||
              sessionModel.session?.speedLimitUpEnabled == true;

      return ListView(children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0),
          child: Text(localizations.appSettings,
              style: Theme.of(context).textTheme.titleLarge),
        ),
        ListTile(
            onTap: () => showThemeDialog(context),
            leading: const Icon(Icons.dark_mode),
            title: Text(localizations.theme),
            subtitle: Text(app.theme.name.capitalize())),
        ListTile(
            onTap: () => showLocaleDialog(context),
            leading: const Icon(Icons.language),
            title: Text(localizations.language),
            subtitle: Text(localeNames[app.locale] ?? app.locale)),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 16),
          child: Text(localizations.torrentsSettings,
              style: Theme.of(context).textTheme.titleLarge),
        ),
        ListTile(
            onTap: () => handlePickFolder(context),
            leading: const Icon(Icons.folder_open),
            title: Text(localizations.downloadDirectory),
            subtitle: Text(downloadDir)),
        if (Platform.isAndroid)
          ListTile(
              onTap: () => handleRequestStorageAccess(context),
              leading: const Icon(Icons.sd_storage),
              title: Text(localizations.allFilesAccess),
              subtitle: Text(hasFullStorageAccess
                  ? localizations.allFilesAccessGranted
                  : localizations.allFilesAccessDescription),
              trailing: hasFullStorageAccess
                  ? const Icon(Icons.check_circle, color: Colors.lightGreen)
                  : null),
        ListTile(
            onTap: showMaximumActiveDownloadDialog,
            leading: const Icon(Icons.downloading),
            title: Text(localizations.maxActiveDownloads),
            subtitle: Text(downloadQueueSize.toString())),
        ListTile(
          leading: const Icon(Icons.speed),
          title: Text(
            localizations.enableSpeedLimits,
          ),
          subtitle: Text(
            localizations.speedLimitsDescription,
          ),
          trailing: Switch(
              value: isSpeedLimitEnabled,
              onChanged: (bool _) {
                _handleEnableSpeedLimits(!isSpeedLimitEnabled);
              }),
        ),
        ListTile(
            enabled: isSpeedLimitEnabled,
            onTap: showSpeedLimitDownDialog,
            leading: const Icon(Icons.arrow_circle_down),
            title: Text(localizations.downloadSpeedLimit),
            subtitle: Text(
                '${sessionModel.session?.speedLimitDown.toString()} ${localizations.kilobytesPerSecond}')),
        ListTile(
            enabled: isSpeedLimitEnabled,
            onTap: showSpeedLimitUpDialog,
            leading: const Icon(Icons.arrow_circle_up),
            title: Text(localizations.uploadSpeedLimit),
            subtitle: Text(
                '${sessionModel.session?.speedLimitUp.toString()} ${localizations.kilobytesPerSecond}')),
        ListTile(
            leading: const Icon(Icons.settings),
            trailing: Switch(
                value: showAdvancedSettings,
                onChanged: (v) => {
                      setState(() {
                        showAdvancedSettings = !showAdvancedSettings;
                      })
                    }),
            title: Text(localizations.showAdvancedSettings)),
        if (showAdvancedSettings) ...[
          ListTile(
              onTap: showPeerPortDialog,
              leading: const Icon(Icons.arrow_right_alt),
              title: Text(localizations.listeningPort),
              subtitle: Text(peerPort.toString())),
        ],
        ListTile(
            onTap: showResetTorrentsSettingsDialog,
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(localizations.resetTorrentsSettings)),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, top: 16),
          child: Text(localizations.about,
              style: Theme.of(context).textTheme.titleLarge),
        ),
        ListTile(
            leading: const Icon(Icons.bolt),
            // onTap: () => showThemeDialog(context),
            title: Text(localizations.version),
            subtitle: Text(app.version)),
      ]);
    });
  }
}
