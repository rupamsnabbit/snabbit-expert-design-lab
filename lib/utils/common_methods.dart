// import 'package:cart/providers/slot.dart';
import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snabbit_runner/main.dart';
import 'package:snabbit_runner/models/web_view_args.dart';
import 'package:snabbit_runner/pages/app_web_view_page.dart';
import 'package:snabbit_runner/pages/payout/payout_home.dart';
import 'package:snabbit_runner/providers/user_profile.dart';
import 'package:snabbit_runner/services/monitoring/monitoring_service_helper.dart';
import 'package:snabbit_runner/services/notification_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/providers/payout.dart';
import 'package:snabbit_runner/services/file_ops.dart';
import 'package:snabbit_runner/services/globals.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_keys.dart';
import 'package:snabbit_runner/services/remote_config/remote_config_service.dart';
import 'package:snabbit_runner/services/server_requests/calling_service.dart';
import 'package:snabbit_runner/utils/app_strings.dart';
import 'package:snabbit_runner/utils/webview_routes.dart';
import 'package:snabbit_runner/widgets/common_bottomsheet_setup.dart';
import 'package:snabbit_runner/widgets/job_login/sefie_error.dart';
import 'package:snabbit_runner/widgets/payout/current_period_view.dart';

import '../services/payout_http.dart';
import 'enums.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:device_info_plus/device_info_plus.dart';

TimeOfDay timeOfDayFromString(String timeString) {
  // Split the string by the colon
  final parts = timeString.split(':');
  // Extract hour and minute from the parts
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);

  // Return a TimeOfDay object
  return TimeOfDay(hour: hour, minute: minute);
}

String timeOfDayToString(TimeOfDay timeOfDay) {
  return "${timeOfDay.hour}:${timeOfDay.minute}:00";
}

String formatTimeOfDay(TimeOfDay time) {
  int hour12Format;
  if (time.hour > 12) {
    hour12Format = time.hour - 12;
  } else {
    hour12Format = time.hour;
  }
  final hour = hour12Format.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

void showSnackbar(BuildContext context, String message,
    {int durationInSeconds = 3}) {
  final scaffoldMessenger = ScaffoldMessenger.of(context);

  // Hide the current Snackbar, if any
  scaffoldMessenger.hideCurrentSnackBar();

  // Show the new Snackbar
  scaffoldMessenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: Duration(seconds: durationInSeconds),
    ),
  );
}

String formatTimeOfDayAmPm(TimeOfDay time) {
  final hour = time.hourOfPeriod.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final period = time.period == DayPeriod.am ? 'am' : 'pm';
  return '$hour:$minute $period';
}

/// Parses [payout_info.check_in_time]: ISO-8601 string (preferred), epoch ms
/// ([num] from JSON), or legacy "h:mm a" IST wall time (same convention as job timer).
DateTime? parsePayoutCheckInTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();
  if (raw is num) {
    final v = raw.round();
    if (v > 1000000000000) {
      return DateTime.fromMillisecondsSinceEpoch(v, isUtc: true).toLocal();
    }
    if (v > 1000000000) {
      return DateTime.fromMillisecondsSinceEpoch(v * 1000, isUtc: true)
          .toLocal();
    }
    return null;
  }
  if (raw is String) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso.toLocal();
    try {
      final parsed = DateFormat('h:mm a').parse(s.toUpperCase());
      final nowUtc = DateTime.now().toUtc();
      int totalMinutes = parsed.hour * 60 + parsed.minute - (5 * 60 + 30);
      if (totalMinutes < 0) totalMinutes += 24 * 60;
      final utcHour = totalMinutes ~/ 60;
      final utcMinute = totalMinutes % 60;
      return DateTime.utc(
              nowUtc.year, nowUtc.month, nowUtc.day, utcHour, utcMinute)
          .toLocal();
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// "h:mm a" in local time for check-in pills (from [parsePayoutCheckInTime]).
String? formatPayoutCheckInTimeDisplay(DateTime? dt) {
  if (dt == null) return null;
  return DateFormat('h:mm a').format(dt);
}

Future<String?> getBatteryLevel() async {
  try {
    final battery = Battery();
    final batteryLevel = await battery.batteryLevel;
    return batteryLevel.toString();
  } catch (e) {
    return null;
  }
}

int getNumberOfDaysExcludingFutureDays(DateTime startDate, DateTime endDate) {
  final today = DateTime.now();

  // Clamp the endDate to today if it's in the future
  final effectiveEndDate = endDate.isAfter(today) ? today : endDate;

  // If the range is invalid (e.g., startDate > effectiveEndDate), return 0
  if (startDate.isAfter(effectiveEndDate)) {
    return 0;
  }

  // Calculate the number of days between the clamped startDate and effectiveEndDate
  return effectiveEndDate.difference(startDate).inDays + 1;
}

// int daysPassedInWeek(DateTime date) {
//   // Get today's date without time
//   DateTime today = DateTime(date.year, date.month, date.day);
//   // Get the Monday of the current week
//   DateTime startOfWeek = today.subtract(Duration(days: today.weekday - 1));
//
//   // Count days from Monday to today
//   return today.difference(startOfWeek).inDays + 1;
// }

// int daysPassedInMonth(DateTime date) {
//   // Get today's date without time
//   DateTime today = DateTime(date.year, date.month, date.day);
//   // First day of the current month
//   DateTime startOfMonth = DateTime(today.year, today.month, 1);
//
//   // Count days from the 1st of the month to today
//   return today.difference(startOfMonth).inDays + 1;
// }

int daysInCurrentMonth(DateTime date) {
  // Get the first day of the next month
  DateTime firstDayOfNextMonth = DateTime(date.year, date.month + 1, 1);

  // Subtract one day to get the last day of the current month
  DateTime lastDayOfCurrentMonth =
      firstDayOfNextMonth.subtract(Duration(days: 1));

  // Return the day number (which represents the total days in the month)
  return lastDayOfCurrentMonth.day;
}

// int? anyValueToInt(dynamic val) {
//   try {
//     return int.tryParse(val.toString()) ?? double.tryParse(val.toString())?.toInt();
//   } catch(e) {
//     return null;
//   }
// }

int? anyValueToInt(dynamic value) {
  try {
    if (value is int) {
      return value; // Already an int, return as is
    }
    if (value is double) {
      return value.toInt(); // Convert double to int
    }
    if (value is String) {
      return int.tryParse(value) ?? double.tryParse(value)?.toInt();
    }
    return null; // Cannot be converted to int
  } catch (e) {
    return null;
  }
}

/// Parses a DateTime from API values — accepts epoch-ms integer or ISO-8601 string.
DateTime? parseDateTime(dynamic value) {
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

String? createNegativeAmount(int? val) {
  try {
    String sign = '';
    if (val != null && val < 0) {
      sign = "-";
    }
    return "$sign₹${val!.abs()}";
  } catch (e) {
    return null;
  }
}

num minsToHours(dynamic val) {
  try {
    int? mins = anyValueToInt(val);
    if (mins == null) return 0;

    double hours = mins / 60;

    // If it's a whole number, return it as int; otherwise, return a rounded decimal.
    return hours % 1 == 0
        ? hours.toInt()
        : double.parse(hours.toStringAsFixed(2));
  } catch (e) {
    return 0;
  }
}

Future<void> updatePayoutHome(PayoutProvider payoutProvider,
    CurrentPeriodProvider currentPeriodProvider) async {
  try {
    payoutProvider.updateLoading(true);
    Response? response = await PayoutHttp.getPayout(
      start: payoutProvider.payoutPeriod == PayoutPeriod.monthly
          ? currentPeriodProvider.monthStartDate
          : currentPeriodProvider.currentDate,
      end: payoutProvider.payoutPeriod == PayoutPeriod.monthly
          ? currentPeriodProvider.monthEndDate
          : currentPeriodProvider.currentDate,
    );
    if (response != null) {
      // error = null;
      // print(response.data);
      currentPeriodProvider.prevSelectedStartDate =
          currentPeriodProvider.monthStartDate;
      currentPeriodProvider.prevSelectedEndDate =
          currentPeriodProvider.monthEndDate;
      payoutProvider.setEarnings(response.data);
      payoutProvider.updateLoading(false);
    } else {
      payoutProvider.updateLoading(false);
    }
  } catch (e) {
    payoutProvider.updateLoading(false);
  }
}

String formatTime(int seconds) {
  try {
    bool isNegative = seconds < 0;
    seconds = seconds.abs();

    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;

    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = remainingSeconds.toString().padLeft(2, '0');

    String formattedTime = '$minutesStr:$secondsStr';

    return isNegative ? '-$formattedTime' : formattedTime;
  } catch (e) {
    return "";
  }
}

Future<void> launchDialer(String? phoneNumber) async {
  await CallUtils.handleCallInitiation(
    phoneNumber: phoneNumber ??
        RemoteConfigService.instance.getString(
            RemoteConfigKeys.expertSosContactNumber,
            defaultValue: "+919004108043"),
    callSourceLabel: "COMMON_METHODS",
  );
}

String formatDateRange(DateTime? startDay, DateTime? endDay) {
  try {
    if (startDay == null || endDay == null) return "";

    // If both dates are the same, fallback to formatSingleDate
    if (startDay.year == endDay.year &&
        startDay.month == endDay.month &&
        startDay.day == endDay.day) {
      return formatSingleDate(startDay);
    }
    String startDayFormatted = "${startDay.day}${getDaySuffix(startDay.day)}";
    String endDayFormatted = "${endDay.day}${getDaySuffix(endDay.day)}";
    String month = DateFormat('MMMM').format(startDay);

    return "$startDayFormatted - $endDayFormatted $month";
  } catch (e) {
    return "";
  }
}

String getDaySuffix(int day) {
  if (day >= 11 && day <= 13) {
    return "th";
  }
  switch (day % 10) {
    case 1:
      return "st";
    case 2:
      return "nd";
    case 3:
      return "rd";
    default:
      return "th";
  }
}

String formatSingleDate(DateTime? date) {
  try {
    String dayFormatted = "${date!.day}${getDaySuffix(date.day)}";
    String month = DateFormat('MMMM').format(date);
    String year = DateFormat('yyyy').format(date);

    return "$dayFormatted $month $year";
  } catch (e) {
    return "";
  }
}

int? getLeaveDuration(DateTime? startDate, DateTime? endDate) {
  try {
    return endDate!.difference(startDate!).inDays + 1;
  } catch (e) {
    return null;
  }
}

String formatSingleDateShortMonth(DateTime? date) {
  try {
    String dayFormatted = "${date!.day}${getDaySuffix(date.day)}";
    String month = DateFormat('MMM').format(date);
    String year = DateFormat('yyyy').format(date);

    return "$dayFormatted $month $year";
  } catch (e) {
    return "";
  }
}

String formatIndianCurrency(int? amount, {bool showSymbol = true}) {
  try {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'en_IN', // Indian locale
      symbol: showSymbol ? '₹' : '', // Currency symbol
      decimalDigits: 0, // No decimal places
    );
    return formatter.format(amount);
  } catch (e) {
    return "";
  }
}

String formatIndianCurrency2(double? amount, {bool showSymbol = true}) {
  try {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'en_IN', // Indian locale
      symbol: showSymbol ? '₹' : '', // Currency symbol
      decimalDigits: 2, // No decimal places
    );
    return formatter.format(amount);
  } catch (e) {
    return "";
  }
}

String formatTrainingDate(DateTime date) {
  // Format the day with suffix (1st, 2nd, 3rd, etc.)
  String day = DateFormat('d').format(date);
  int dayNumber = int.parse(day);
  // Format the month name
  String month = DateFormat('MMMM').format(date);

  return "$day${getDaySuffix(dayNumber)} $month";
}

String trainingDayDateTimeRep(DateTime? dateTime) {
  try {
    String day = DateFormat('d').format(dateTime!);
    int dayNumber = int.parse(day);
    String weekday = DateFormat('EEEE').format(dateTime); // Monday
    String month = DateFormat('MMMM').format(dateTime); // March
    String time = DateFormat('h:mm a').format(dateTime); // 9:00 AM

    return "$weekday, $day${getDaySuffix(dayNumber)} $month at $time";
  } catch (e) {
    return "";
  }
}

DateTime? convertDateAndTimeToDateTime(String? dateStr, String? timeStr) {
  if (dateStr == null ||
      dateStr.isEmpty ||
      timeStr == null ||
      timeStr.isEmpty) {
    return null;
  }

  try {
    // Combine date and time with 'T' separator (ISO 8601 format)
    final dateTimeStr = '${dateStr}T$timeStr';

    // Parse the date-time string
    return DateTime.parse(dateTimeStr);
  } catch (e) {
    return null;
  }
}

String formatDateToDayMonth(DateTime? date) {
  try {
    String dayFormatted = "${date!.day}${getDaySuffix(date.day)}";
    String month = DateFormat('MMMM').format(date);

    return "$dayFormatted $month";
  } catch (e) {
    return "";
  }
}

// Helper method to check if two dates are the same day
bool isSameDay(DateTime date1, DateTime date2) {
  return date1.year == date2.year &&
      date1.month == date2.month &&
      date1.day == date2.day;
}

// Helper extension
extension StringCapitalize on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}

int countLeapYearsBetween(DateTime start, DateTime end) {
  int leapCount = 0;

  for (int year = start.year; year <= end.year; year++) {
    if (_isLeapYear(year)) {
      leapCount++;
    }
  }

  return leapCount;
}

bool _isLeapYear(int year) {
  return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
}

void playSoundOnReceivingNewJob(Response? response, {bool isFg = true}) async {
  // In the background/killed-state isolate (isFg: false), audio is already
  // handled by loopSound(message: message) in the FCM handler. Skip here to
  // avoid writing 'stopped' and killing that ongoing audio loop.
  if (!isFg) return;
  try {
    await ensureNewJobLoopSound(
      isNewJob: response?.data['widget_name'] == 'RUNNER_NEW_JOB',
      response: response,
    );
  } catch (_) {
    await FileStorage.writeState('stopped');
  }
}

/// (Re)arms — or stops — the looping new-job alert as a pure function of whether
/// a new job is currently pending. This is the single re-arm primitive shared by
/// both cohorts, so the sound behaves identically regardless of how the job is
/// discovered:
///
///  1. Flutter/poll cohort — [playSoundOnReceivingNewJob], fired from every
///     `current_state` fetch (initial + 60s poll + resume).
///  2. KMP/mqtt cohort — `JobOverlayChannel` (`newJobAlertStart`), invoked by
///     `JobScreenLauncherPlugin`'s store observer when the runner-state ENTERS
///     `RUNNER_NEW_JOB`. That cohort suppresses the Dart poll, so it never reaches
///     path 1; driving this off the observed state restores the same "play on open /
///     while a job is pending" behaviour.
///
/// [isNewJob] true → reset to a clean 'stopped' base and let any in-flight
/// (possibly cross-isolate) loop tear down for 1s — mirrors the original poll
/// re-arm — then start the loop via [loopSound]. false → mark 'stopped' so a
/// running loop halts on its next tick. [loopSound] is intentionally NOT awaited
/// (it installs a long-lived periodic timer), matching the original behaviour.
///
/// The 1s re-arm is guarded by [_newJobLoopRequestId]: a stop that lands inside the
/// delay (the KMP path dispatches START and STOP independently, so an offer resolving
/// within ~1s of opening can interleave) bumps the id and vetoes the parked re-arm, so
/// the loop is never resurrected for an already-resolved offer by a late 'playing' write.
Future<void> ensureNewJobLoopSound({
  required bool isNewJob,
  Response? response,
}) async {
  if (isNewJob) {
    final requestId = ++_newJobLoopRequestId;
    await FileStorage.writeState('stopped');
    await Future.delayed(const Duration(seconds: 1));
    // A stop (or a newer arm) landed during the re-arm above → this request is stale.
    if (requestId != _newJobLoopRequestId) return;
    loopSound(response: response, forceNewJobNotification: true);
  } else {
    cancelPendingNewJobLoop();
    await FileStorage.writeState('stopped');
  }
}

/// Monotonic id for each new-job loop *arm* request. START ([ensureNewJobLoopSound]
/// with `isNewJob: true`) snapshots this before its 1s re-arm delay and only starts
/// [loopSound] if the snapshot is still current afterward.
int _newJobLoopRequestId = 0;

/// Invalidate any parked new-job loop re-arm (the 1s delay in [ensureNewJobLoopSound]),
/// so a stop landing in that window can't be overwritten by the late 'playing' write.
/// Called by [silenceNewJobAlert], which stops the loop directly rather than through
/// [ensureNewJobLoopSound].
void cancelPendingNewJobLoop() => _newJobLoopRequestId++;

//fetchLocation
Future<geo.Position?> fetchCurrentLocation() async {
  bool serviceEnabled;
  geo.LocationPermission permission;
  geo.Position position;

  try {
    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();

    if (serviceEnabled) {
      permission = await geo.Geolocator.checkPermission();

      if ([geo.LocationPermission.always, geo.LocationPermission.whileInUse]
          .contains(permission)) {
        position = await geo.Geolocator.getCurrentPosition(
            locationSettings: geo.LocationSettings(
          accuracy: geo.LocationAccuracy.best,
          timeLimit: const Duration(seconds: 5),
        ));

        return position;
      }
    }
  } catch (e) {
    return null;
  }
  return null;
}

Future<void> stopAudio() async {
  await FileStorage.writeState('stopped');
  await NotificationService.instance.cancelAll();
  await GlobalState().audioPlayer.setReleaseMode(ReleaseMode.stop);
  await GlobalState().audioPlayer.stop();
}

/// Hard-stops the looping new-job alert: vetoes any parked re-arm (START's 1s delay)
/// then tears down the state marker, notification and audio player now. The single
/// stop implementation shared by the KMP new-job STOP edge (`JobOverlayChannel`, fired
/// by `JobScreenLauncherPlugin`'s store observer when the state leaves `RUNNER_NEW_JOB`)
/// and the Profile "Silent notifications" tile (`ProfileActionsChannel`).
Future<void> silenceNewJobAlert() async {
  cancelPendingNewJobLoop();
  await stopAudio();
}

/// In-app player volume (0.0–1.0) passed to every `.play()` call. Normally
/// full; in [kDebugMode] the debug menu's sound-volume picker can lower it
/// via [GlobalState.debugSoundVolume] (e.g. to keep dev/QA devices quiet).
double get desiredVolume =>
    kDebugMode ? (GlobalState().debugSoundVolume ?? 1.0) : 1.0;

/// Takes a list of Strings, maps them to day names, and constructs a sentence.
/// [Monday] => 'Monday'
/// [Monday, Tuesday] => 'Monday and Tuesday'
/// [Monday, Tuesday, Wednesday] => 'Monday, Tuesday and Wednesday'
String constructDaysSentence(
  List<String> days,
  LanguageProvider languageProvider,
) {
  final dayNames = days
      .map((d) => languageProvider.getMessage(
            d,
            d,
          ))
      .cast<String>()
      .toList();

  if (dayNames.isEmpty) return '';
  if (dayNames.length == 1) return dayNames.first;
  if (dayNames.length == 2) return '${dayNames[0]} & ${dayNames[1]}';
  return dayNames.sublist(0, dayNames.length - 1).join(', ') +
      ' & ' +
      dayNames.last;
}

Future<void> skipUpdate() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.setInt(AppStrings.versionCodeSkipped,
      GlobalState().appConfig?.skipAndroidVersion ?? 0);
}

Color? hexToColor(String? hexString) {
  try {
    hexString = hexString!.toUpperCase().replaceAll("#", "");

    if (hexString.length == 6) {
      hexString = "FF$hexString"; // Add alpha if missing
    }

    return Color(int.parse(hexString, radix: 16));
  } catch (e) {
    return null;
  }
}

void setMaxVolume() async {
  // In kDebugMode, when the debug menu's sound-volume override is set, keep
  // dev/QA devices quiet — don't force the device streams back to max.
  if (kDebugMode && GlobalState().debugSoundVolume != null) {
    return;
  }
  try {
    final v1 =
        await FlutterVolumeController.getVolume(stream: AudioStream.system);
    final v2 =
        await FlutterVolumeController.getVolume(stream: AudioStream.ring);
    final v3 =
        await FlutterVolumeController.getVolume(stream: AudioStream.music);
    final v4 =
        await FlutterVolumeController.getVolume(stream: AudioStream.alarm);
    if ((v1 != null && v1 < 1.0) ||
        (v2 != null && v2 < 1.0) ||
        (v3 != null && v3 < 1.0) ||
        (v4 != null && v4 < 1.0)) {
      FlutterVolumeController.setVolume(1.0, stream: AudioStream.system);
      FlutterVolumeController.setVolume(1.0, stream: AudioStream.ring);
      FlutterVolumeController.setVolume(1.0, stream: AudioStream.music);
      FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
    }
  } catch (e) {
    FlutterVolumeController.setVolume(1.0, stream: AudioStream.system);
    FlutterVolumeController.setVolume(1.0, stream: AudioStream.ring);
    FlutterVolumeController.setVolume(1.0, stream: AudioStream.music);
    FlutterVolumeController.setVolume(1.0, stream: AudioStream.alarm);
  }
}

Future<String?> getDeviceId() async {
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.id; // OR androidInfo.androidId (more stable)
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return iosInfo.identifierForVendor; // Unique per app install
  } else {
    return null;
  }
}

FontWeight? mapIntToFontWeight(int? weight) {
  if (weight == null) return null;

  switch (weight) {
    case 100:
      return FontWeight.w100;
    case 200:
      return FontWeight.w200;
    case 300:
      return FontWeight.w300;
    case 400:
      return FontWeight.w400;
    case 500:
      return FontWeight.w500;
    case 600:
      return FontWeight.w600;
    case 700:
      return FontWeight.w700;
    case 800:
      return FontWeight.w800;
    case 900:
      return FontWeight.w900;
    default:
      // Map common weight names to nearest values
      if (weight <= 100) return FontWeight.w100;
      if (weight <= 200) return FontWeight.w200;
      if (weight <= 300) return FontWeight.w300;
      if (weight <= 400) return FontWeight.w400;
      if (weight <= 500) return FontWeight.w500;
      if (weight <= 600) return FontWeight.w600;
      if (weight <= 700) return FontWeight.w700;
      if (weight <= 800) return FontWeight.w800;
      return FontWeight.w900;
  }
}

TextStyle? getThemeTextStyleByName(BuildContext context, String? styleName) {
  if (styleName == null) return null;

  final textTheme = Theme.of(context).textTheme;

  switch (styleName.toLowerCase()) {
    case 'displaylarge':
      return textTheme.displayLarge;
    case 'displaymedium':
      return textTheme.displayMedium;
    case 'displaysmall':
      return textTheme.displaySmall;
    case 'headlinelarge':
      return textTheme.headlineLarge;
    case 'headlinemedium':
      return textTheme.headlineMedium;
    case 'headlinesmall':
      return textTheme.headlineSmall;
    case 'titlelarge':
      return textTheme.titleLarge;
    case 'titlemedium':
      return textTheme.titleMedium;
    case 'titlesmall':
      return textTheme.titleSmall;
    case 'labellarge':
      return textTheme.labelLarge;
    case 'labelmedium':
      return textTheme.labelMedium;
    case 'labelsmall':
      return textTheme.labelSmall;
    case 'bodylarge':
      return textTheme.bodyLarge;
    case 'bodymedium':
      return textTheme.bodyMedium;
    case 'bodysmall':
      return textTheme.bodySmall;
    default:
      return null;
  }
}

TextAlign getTextAlignFromString(String? alignmentString) {
  if (alignmentString == null) return TextAlign.center;

  switch (alignmentString.toLowerCase()) {
    case 'left':
      return TextAlign.left;
    case 'right':
      return TextAlign.right;
    case 'center':
      return TextAlign.center;
    case 'justify':
      return TextAlign.justify;
    case 'start':
      return TextAlign.start;
    case 'end':
      return TextAlign.end;
    default:
      return TextAlign.center;
  }
}

double? anyValueToDouble(dynamic value) {
  try {
    if (value is double) {
      return value; // Already a double
    }
    if (value is int) {
      return value.toDouble(); // Convert int to double
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null; // Cannot be converted to double
  } catch (e) {
    return null;
  }
}

String formatDayWithSuffix(DateTime date) {
  final day = date.day;
  String suffix;
  if (day >= 11 && day <= 13) {
    suffix = 'th';
  } else {
    switch (day % 10) {
      case 1:
        suffix = 'st';
        break;
      case 2:
        suffix = 'nd';
        break;
      case 3:
        suffix = 'rd';
        break;
      default:
        suffix = 'th';
        break;
    }
  }
  return DateFormat("d'$suffix' MMMM").format(date);
}

/// Shows a custom toast using [fluttertoast], removes existing toasts, and displays the given [widget].
/// [context] is required for theming and positioning.
/// [widget] is the custom widget to display in the toast.
/// [positionedToastBuilder] can be optionally provided for custom positioning, otherwise defaults to bottom center.
void showCustomToast({
  required BuildContext context,
  required Widget widget,
  double? bottomPosition,
}) {
  final fToast = FToast();
  fToast.init(context);
  fToast.removeCustomToast();
  fToast.removeQueuedCustomToasts();
  fToast.showToast(
    child: widget,
    positionedToastBuilder: (context, child, _) {
      return Positioned(
        bottom: bottomPosition ?? 60,
        left: 0,
        right: 0,
        child: Center(child: child),
      );
    },
  );
}

String maskAccountNumber(String accountNumber) {
  // Removes any non-digit characters to ensure clean input.
  String digitsOnly = accountNumber.replaceAll(RegExp(r'\D'), '');

  // Returns an empty string if the number is invalid.
  if (digitsOnly.length < 4) {
    return '';
  }

  // Gets the last four digits of the account number.
  String lastFour = digitsOnly.substring(digitsOnly.length - 4);

  // Calculates the number of 'X' characters for the masked part.
  int maskedLength = digitsOnly.length - 4;

  // Builds the masked string by grouping 'X' characters.
  String maskedPart = '';
  for (int i = 0; i < maskedLength; i++) {
    maskedPart += 'X';
    // Add a space after every four 'X's, except at the very beginning.
    if ((i + 1) % 4 == 0 && i < maskedLength - 1) {
      maskedPart += ' ';
    }
  }

  // Returns the final formatted string.
  return '$maskedPart $lastFour';
}

void showSelfieError(List<String> errors, BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return CommonBottomSheetSetup(
          child: Padding(
        padding: EdgeInsets.symmetric(vertical: 26.h),
        child: SelfieError(
          errors: errors,
        ),
      ));
    },
  );
}

void _openWebView({
  required String? url,
  required String title,
  bool fetchLocation = false,
  void Function()? onDrawerClick,
  void Function()? onPageLoaded,
  void Function(String reason)? onPageLoadFailed,
  void Function(String url, bool success)? onExternalUrlOpened,
  required BuildContext context,
}) {
  if (url == null || url.isEmpty) return;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') {
    showSnackbar(context, 'Insecure URL, cannot be opened');
    return;
  }
  onDrawerClick?.call();
  Navigator.of(context).pushNamed(
    AppWebViewPage.routeName,
    arguments: WebViewArgs(
      url: url,
      title: title,
      fetchLocation: fetchLocation,
      onPageLoaded: onPageLoaded,
      onPageLoadFailed: onPageLoadFailed,
      onExternalUrlOpened: onExternalUrlOpened,
    ),
  );
}

void navigateToEarningsPage(BuildContext context) {
  try {
    final userProfileProvider = context.read<UserProfileProvider>();
    if (userProfileProvider.isRateCardV2Effective) {
      _openWebView(
        url: buildWebviewUrl(
          WebviewRoutes.payoutsMonthlySummary,
        ),
        title: 'Earnings',
        context: context,
      );
    } else {
      Navigator.of(context).pushNamed(
        PayoutHome.routeName,
      );
    }
  } catch (e, st) {
    MonitoringServiceHelper.logError(e.toString(), {
      "stacktrace": st.toString(),
    });
  }
}
