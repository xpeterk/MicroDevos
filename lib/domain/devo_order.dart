import 'models/devo.dart';

/// Newest edition first, and within an edition position 1 through 8.
///
/// The Supabase client’s `order` defaults to descending, so a position sort
/// that forgets `ascending: true` comes back 8…1. Callers sort again here.
List<Devo> devosInReadingOrder(Iterable<Devo> devos) {
  final ordered = [...devos];
  ordered.sort((a, b) {
    final byDate = b.editionDate.compareTo(a.editionDate);
    if (byDate != 0) return byDate;
    return a.position.compareTo(b.position);
  });
  return ordered;
}
