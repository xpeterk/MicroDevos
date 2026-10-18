import 'models/devo.dart';

/// Picks which edition Today should open.
///
/// [editionsNewestFirst] is a list of edition dates, newest first. When the
/// reader has not chosen a date, Today uses the latest edition on or before
/// [today]. Weekends therefore fall back to Friday.
DateTime? resolveEditionDate({
  required DateTime today,
  required List<DateTime> editionsNewestFirst,
  DateTime? selected,
}) {
  if (selected != null) {
    return DateTime(selected.year, selected.month, selected.day);
  }
  if (editionsNewestFirst.isEmpty) return null;
  final todayDate = DateTime(today.year, today.month, today.day);
  for (final edition in editionsNewestFirst) {
    final day = DateTime(edition.year, edition.month, edition.day);
    if (!day.isAfter(todayDate)) return day;
  }
  final oldest = editionsNewestFirst.last;
  return DateTime(oldest.year, oldest.month, oldest.day);
}

bool editionIsFallback({
  required DateTime today,
  required DateTime edition,
  required bool readerChoseDate,
}) {
  if (readerChoseDate) return false;
  return !isSameDate(today, edition);
}
