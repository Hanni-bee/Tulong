import 'package:intl/intl.dart';

/// Centralized time formatting so the app consistently uses 12-hour time (AM/PM).
class AppTimeFormat {
  /// 12-hour time, e.g. "3:07 PM"
  static String time(DateTime dt) => DateFormat('h:mm a').format(dt);

  /// 12-hour time with seconds, e.g. "3:07:12 PM"
  static String timeWithSeconds(DateTime dt) => DateFormat('h:mm:ss a').format(dt);

  /// Date + time, e.g. "Jan 9, 3:07 PM"
  static String monthDayTime(DateTime dt) => DateFormat('MMM d, h:mm a').format(dt);
}


