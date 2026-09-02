import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
// import 'package:installed_apps/app_info.dart';
// import 'package:installed_apps/installed_apps.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import '../utils/app_strings.dart';
import 'runner_http.dart';

class FileStorage {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/notification_audio_state.txt');
  }

  static Future<String> readState() async {
    try {
      final file = await _localFile;
      return await file.readAsString();
    } catch (e) {
      return 'stopped'; // default state
    }
  }

  static Future<File> writeState(String state) async {
    final file = await _localFile;
    return file.writeAsString(state);
  }
}

/// Helper method to check if 24 hours have passed since last sync
Future<bool> shouldSyncData(String timestampKey) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();

  // Get the last sync timestamp (0 if never synced)
  int lastSyncTimestamp = prefs.getInt(timestampKey) ?? 0;
  int currentTimestamp = DateTime.now().millisecondsSinceEpoch;

  // Check if 24 hours (86400000 milliseconds) have passed
  int twentyFourHoursInMs = 24 * 60 * 60 * 1000;
  bool shouldSync =
      (currentTimestamp - lastSyncTimestamp) >= twentyFourHoursInMs;

  return shouldSync;
}

/// Helper method to update last sync timestamp
Future<void> updateLastSyncTimestamp(String timestampKey) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
  await prefs.setInt(timestampKey, currentTimestamp);
}

Future<void> getContacts() async {
  try {
    // Check if 24 hours have passed since last sync
    bool shouldSync =
        await shouldSyncData(AppStrings.contactsLastSyncTimestamp);
    if (!shouldSync) {
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();

    // First request contacts permission
    final contactsStatus = await Permission.contacts.request();

    // Then, in the same flow, also request microphone permission so it is
    // available for features that depend on it (e.g. foreground service).
    await Permission.microphone.request();

    MonitoringServiceHelper.logInfo(
      'Contacts Permission Request',
      {
        'component': 'FileOps',
        'status': contactsStatus.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    if (contactsStatus.isGranted) {
      try {
        MonitoringServiceHelper.logInfo(
          'Contacts Fetch Started',
          {
            'component': 'FileOps',
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        Iterable<Contact> contacts =
            await FlutterContacts.getContacts(withProperties: true);
        List<Contact> contactList = contacts.toList();
        String filePath = await saveContactsToFile(contactList);

        MonitoringServiceHelper.logInfo(
          'Contacts File Created',
          {
            'component': 'FileOps',
            'contactCount': contactList.length,
            'filePath': filePath,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );

        try {
          final response = await RunnerHttp.uploadContactsFile(filePath);
          if (response?.statusCode == 200) {
            await prefs.setBool(AppStrings.contactsUploadedFlag, true);
            await updateLastSyncTimestamp(AppStrings.contactsLastSyncTimestamp);

            MonitoringServiceHelper.logInfo(
              'Contacts Upload Success',
              {
                'component': 'FileOps',
                'contactCount': contactList.length,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          } else {
            MonitoringServiceHelper.logError(
              'Contacts Upload Failed',
              {
                'component': 'FileOps',
                'statusCode': response?.statusCode,
                'timestamp': DateTime.now().toIso8601String(),
              },
            );
          }
        } catch (e) {
          MonitoringServiceHelper.logError(
            'Contacts Upload Error',
            {
              'component': 'FileOps',
              'error': e.toString(),
              'timestamp': DateTime.now().toIso8601String(),
            },
          );
        }
      } catch (e) {
        MonitoringServiceHelper.logError(
          'Contacts Fetch Error',
          {
            'component': 'FileOps',
            'error': e.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } else {
      MonitoringServiceHelper.logWarning(
        'Contacts Permission Denied',
        {
          'component': 'FileOps',
          'status': contactsStatus.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    }
  } catch (e) {
    // DO NOTHING
  }
}

Future<String> saveContactsToFile(List<Contact> contacts) async {
  // Contact field access must stay on the main isolate (plugin objects aren't
  // sendable), but this only builds a lightweight {name, phones} list; the
  // heavier JSON serialization is offloaded to a background isolate below.
  List<Map<String, dynamic>> contactList = contacts.map((contact) {
    return {
      'name': contact.displayName,
      'phones': contact.phones.map((phone) => phone.number).toList(),
    };
  }).toList();

  String jsonContacts = await compute(encodeContactsJson, contactList);

  // Get the directory to store the file
  final directory = await getApplicationDocumentsDirectory();
  final path = '${directory.path}/referral.json';

  // Atomic write: unique temp then rename (atomic on the same volume) so a
  // concurrent reader/writer (periodic sync vs on-demand populate) never sees a
  // partially-written file — racing writers resolve to last-writer-wins.
  final tmp = File('$path.${DateTime.now().microsecondsSinceEpoch}.tmp');
  await tmp.writeAsString(jsonContacts, flush: true);
  await tmp.rename(path);

  return path; // Return the file path
}

/// Serialises the reduced contact list to the referral.json envelope. Top-level
/// so it can run under [compute] on a background isolate.
String encodeContactsJson(List<Map<String, dynamic>> contacts) =>
    jsonEncode({"contacts": contacts});

/// Populates referral.json for the referral picker when nothing has been
/// persisted yet. Unlike [getContacts] this is side-effect free — no BE upload,
/// no microphone request, no 24h throttle. Assumes contacts permission is
/// already granted by the caller; only the name + first phone are read
/// downstream, so the heavier plugin work is skipped.
///
/// Gated on *file existence*, not the reduced list being empty: a genuinely
/// empty phonebook (or one with no phone numbers) still writes a valid,
/// reduce-empty referral.json, so without this gate the picker would re-fetch
/// the whole phonebook on every open for such users. Keeping an existing file
/// fresh is the 24h periodic sync's job, not this on-demand path.
Future<void> refreshContactsFile() async {
  final directory = await getApplicationDocumentsDirectory();
  if (await File('${directory.path}/referral.json').exists()) return;

  final contacts = await FlutterContacts.getContacts(
    withProperties: true,
    withThumbnail: false,
    withPhoto: false,
    withGroups: false,
    withAccounts: false,
    deduplicateProperties: false,
  );
  await saveContactsToFile(contacts.toList());
}

/// Reads the contacts already persisted by [getContacts] (referral.json),
/// reduced to the `{name, phone}` shape the webview picker consumes: first
/// non-empty phone (whitespace stripped), de-duplicated across contacts, name
/// trimmed. The JSON decode + reduce runs on a background isolate so a large
/// phonebook can't jank the UI. Returns an empty list on miss/corruption so
/// callers can decide to populate via [getContacts].
Future<List<Map<String, String>>> readReferralContactsFile() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/referral.json');
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    return await compute(reduceStoredContactsJson, content);
  } catch (_) {
    return [];
  }
}

/// Pure decode + reduce of referral.json's raw content into the picker shape.
/// Top-level so it can run under [compute] on a background isolate.
List<Map<String, String>> reduceStoredContactsJson(String content) {
  final decoded = jsonDecode(content);
  if (decoded is! Map) return [];
  final raw = decoded['contacts'];
  if (raw is! List) return [];

  final list = <Map<String, String>>[];
  final seenPhones = <String>{};
  for (final entry in raw) {
    if (entry is! Map) continue;
    final phones = entry['phones'];
    if (phones is! List || phones.isEmpty) continue;
    final first = phones.first;
    if (first == null) continue;
    final phone = first.toString().replaceAll(RegExp(r'\s+'), '');
    if (phone.isEmpty) continue;
    if (!seenPhones.add(phone)) continue;
    list.add({'name': (entry['name'] ?? '').toString().trim(), 'phone': phone});
  }
  return list;
}

// Future<void> getInstalledApps() async {
//   try {
//     // Check if 24 hours have passed since last sync
//     bool shouldSync = await shouldSyncData(AppStrings.appsLastSyncTimestamp);
//     if (!shouldSync) {
//       return;
//     }
//
//     try {
//       MonitoringServiceHelper.logInfo(
//         'Apps Fetch Started',
//         {
//           'component': 'FileOps',
//           'timestamp': DateTime.now().toIso8601String(),
//         },
//       );
//
//       // Get installed apps using installed_apps package
//       List<AppInfo> apps = await InstalledApps.getInstalledApps();
//
//       String filePath = await saveAppsToFile(apps);
//
//       MonitoringServiceHelper.logInfo(
//         'Apps File Created',
//         {
//           'component': 'FileOps',
//           'appCount': apps.length,
//           'filePath': filePath,
//           'timestamp': DateTime.now().toIso8601String(),
//         },
//       );
//
//       try {
//         final response = await RunnerHttp.uploadAppsFile(filePath);
//         if (response?.statusCode == 200) {
//           await updateLastSyncTimestamp(AppStrings.appsLastSyncTimestamp);
//
//           MonitoringServiceHelper.logInfo(
//             'Apps Upload Success',
//             {
//               'component': 'FileOps',
//               'appCount': apps.length,
//               'timestamp': DateTime.now().toIso8601String(),
//             },
//           );
//         } else {
//           MonitoringServiceHelper.logError(
//             'Apps Upload Failed',
//             {
//               'component': 'FileOps',
//               'statusCode': response?.statusCode,
//               'timestamp': DateTime.now().toIso8601String(),
//             },
//           );
//         }
//       } catch (e) {
//         MonitoringServiceHelper.logError(
//           'Apps Upload Error',
//           {
//             'component': 'FileOps',
//             'error': e.toString(),
//             'timestamp': DateTime.now().toIso8601String(),
//           },
//         );
//       }
//     } catch (e) {
//       MonitoringServiceHelper.logError(
//         'Apps Fetch Error',
//         {
//           'component': 'FileOps',
//           'error': e.toString(),
//           'timestamp': DateTime.now().toIso8601String(),
//         },
//       );
//     }
//   } catch(e) {
//     // DO NOTHING
//   }
// }
//
// Future<String> saveAppsToFile(List<AppInfo> apps) async {
//   // Convert app objects to JSON format
//   List<Map<String, dynamic>> appList = apps.map((app) {
//     // Extract data from the dynamic app object
//     return {
//       'name': app.name,
//       'bundle_id': app.packageName,
//       'version_name': app.versionCode.toString(),
//       'version_code': app.versionName,
//       'installed_at': app.installedTimestamp.toString(),
//     };
//   }).toList();
//
//   String jsonApps = jsonEncode({
//     "apps": appList,
//   });
//
//   // Get the directory to store the file
//   final directory = await getApplicationDocumentsDirectory();
//   final path = '${directory.path}/installed_apps.json';
//
//   // Save the JSON data to a file
//   File file = File(path);
//   await file.writeAsString(jsonApps);
//
//   return path; // Return the file path
// }
