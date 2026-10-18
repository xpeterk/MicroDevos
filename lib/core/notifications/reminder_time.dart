/// Next local instant for a daily reminder. If [now] is already past today's
/// chosen time, the result is tomorrow.
DateTime nextReminder(DateTime now, int hour, int minute) {
  final safeHour = hour.clamp(0, 23);
  final safeMinute = minute.clamp(0, 59);
  var scheduled = DateTime(now.year, now.month, now.day, safeHour, safeMinute);
  if (!scheduled.isAfter(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}
