import 'package:external_path/external_path.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:enjambre/engine/engine.dart';
import 'package:enjambre/engine/session.dart';
import 'package:enjambre/storage/shared_preferences.dart';
import 'package:enjambre/utils/device.dart';
import 'package:enjambre/utils/storage.dart';

/// Set once the user picks a download directory, so it is never overridden.
const downloadDirPickedByUserKey = 'downloadDirPickedByUser';

/// Name of the folder created inside the app own storage.
const _fallbackDirName = 'Downloads';

/// The permission that gives plain file access to the shared storage, for the
/// running Android version.
Future<Permission> storagePermission() async {
  return await getAndroidSdkVersion() <= 29
      ? Permission.storage
      : Permission.manageExternalStorage;
}

/// True when the app can read and write the shared storage through plain file
/// paths, which is the only thing transmission knows how to do.
///
/// Up to Android 10 the legacy storage permission is enough. From Android 11
/// on, scoped storage only lets an app touch the files it created itself, and
/// that ownership is lost when the app is reinstalled: transmission then
/// reports its own downloads as missing. "All files access" is what restores
/// plain file access.
Future<bool> hasFullStorageAccess() async {
  return (await storagePermission()).isGranted;
}

/// Shared Downloads folder, visible from a file manager.
Future<String?> publicDownloadDir() async {
  try {
    return await ExternalPath.getExternalStoragePublicDirectory(
        ExternalPath.DIRECTORY_DOWNLOAD);
  } catch (e) {
    debugPrint('default_session: no public download directory: $e');
    return null;
  }
}

/// Folder owned by the app. Writable whatever the storage permissions are, but
/// its content goes away when the app is uninstalled.
Future<String?> privateDownloadDir() async {
  try {
    final dir = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    return p.join(dir.path, _fallbackDirName);
  } catch (e) {
    debugPrint('default_session: no private download directory: $e');
    return null;
  }
}

/// Points transmission at a download directory it can actually write to.
///
/// The default directory transmission picks on Android does not exist, see
/// tr_getDefaultDownloadDir() in platform.cc, so one is always chosen here.
initDefaultDownloadDir(Engine engine) async {
  final session = await engine.fetchSession();
  final currentDir = session.downloadDir;

  // A directory the user picked is left alone, as long as it still works.
  final pickedByUser =
      await SharedPrefsStorage.getBool(downloadDirPickedByUserKey) ?? false;
  if (pickedByUser &&
      currentDir != null &&
      await isDirectoryWritable(currentDir)) {
    return;
  }

  String? downloadDir;

  if (await hasFullStorageAccess()) {
    final publicDir = await publicDownloadDir();
    if (publicDir != null && await isDirectoryWritable(publicDir)) {
      downloadDir = publicDir;
    }
  }

  // Without full access the shared Downloads folder is a trap: transmission
  // can create files there, then lose them on the next install and report
  // every torrent as broken. The app own folder always works.
  downloadDir ??= await privateDownloadDir();

  if (downloadDir == null || downloadDir == currentDir) return;

  debugPrint('default_session: download directory set to $downloadDir');

  await session.update(SessionBase(downloadDir: downloadDir));
}
