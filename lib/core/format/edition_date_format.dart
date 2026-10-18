import 'package:intl/intl.dart';

/// Formats an edition date for the reading screens.
///
/// [DateFormat] throws [LocaleDataException] until [initializeDateFormatting]
/// has run. In release that exception becomes Flutter's grey error box, so a
/// missing locale falls back to the same English labels instead of failing
/// the build.
String formatEditionDate(DateTime date, String pattern) {
  try {
    // en_US symbols ship inside intl. Any other locale throws
    // LocaleDataException until initializeDateFormatting has run, and a
    // release build paints that as a grey box.
    return DateFormat(pattern, 'en_US').format(date);
  } on Object {
    return fallbackEditionDate(date, pattern);
  }
}

String fallbackEditionDate(DateTime date, String pattern) {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  const shortMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[date.weekday - 1];
  final month = months[date.month - 1];
  final shortMonth = shortMonths[date.month - 1];
  return switch (pattern) {
    'EEEE' => weekday,
    'MMMM d, y' => '$month ${date.day}, ${date.year}',
    'EEEE, MMMM d' => '$weekday, $month ${date.day}',
    'MMM d' => '$shortMonth ${date.day}',
    _ =>
      '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
  };
}
