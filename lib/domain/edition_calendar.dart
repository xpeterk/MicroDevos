import 'models/devo.dart';

/// Live devotion rows use these statuses. Ideas are not part of the reader catalog.
/// Matching is case-insensitive. `published` stays so older rows still appear.
const readerDevoStatuses = ['archive', 'read', 'unread', 'published'];

bool isReaderDevoStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return readerDevoStatuses.contains(normalized);
}

/// Picks which edition Today should open.
///
/// When the reader has not chosen a date, Today uses the latest edition on or
/// before the device's local [today], whatever order [editions] arrives in.
/// A Tuesday with no edition of its own opens Monday. A weekend opens Friday.
DateTime? resolveEditionDate({
  required DateTime today,
  required List<DateTime> editions,
  DateTime? selected,
}) {
  if (selected != null) {
    return DateTime(selected.year, selected.month, selected.day);
  }
  if (editions.isEmpty) return null;
  final todayDate = DateTime(today.year, today.month, today.day);
  DateTime? latest;
  DateTime? earliest;
  for (final edition in editions) {
    final day = DateTime(edition.year, edition.month, edition.day);
    if (earliest == null || day.isBefore(earliest)) earliest = day;
    if (day.isAfter(todayDate)) continue;
    if (latest == null || day.isAfter(latest)) latest = day;
  }
  return latest ?? earliest;
}

bool editionIsFallback({
  required DateTime today,
  required DateTime edition,
  required bool readerChoseDate,
}) {
  if (readerChoseDate) return false;
  return !isSameDate(today, edition);
}
