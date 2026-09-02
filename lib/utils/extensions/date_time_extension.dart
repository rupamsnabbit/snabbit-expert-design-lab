import 'package:intl/intl.dart'; // Import for DateFormat

// Extension on DateTime to format time
extension DateTimeExtension on DateTime {
  /// Formats the DateTime object into a time string like "6:00 am" or "7:30 pm".
  String to12HoursMinutes() {
    return DateFormat('h:mm a').format(this);
  }

  /// Formats the DateTime object into a time string like "HH:mm:ss".
  String toHhMmSs() {
    return DateFormat('HH:mm:ss').format(this);
  }
}