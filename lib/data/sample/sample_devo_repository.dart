import '../../domain/devo_order.dart';
import '../../domain/models/devo.dart';
import '../../domain/repositories/repositories.dart';
import 'sample_catalog.dart';

class SampleDevoRepository implements DevoRepository {
  const SampleDevoRepository(this.catalog);

  final SampleCatalog catalog;

  @override
  Future<Devo?> devoById(String id) async {
    for (final devo in catalog.devos) {
      if (devo.id == id) return devo;
    }
    return null;
  }

  @override
  Future<List<Devo>> devosForDate(DateTime date) async {
    final matches = catalog.devos.where(
      (devo) => isSameDate(devo.editionDate, date),
    );
    return devosInReadingOrder(matches);
  }

  @override
  Future<List<DateTime>> editionDates() async {
    final dates = <String, DateTime>{};
    for (final devo in catalog.devos) {
      dates[devo.dateKey] = DateTime(
        devo.editionDate.year,
        devo.editionDate.month,
        devo.editionDate.day,
      );
    }
    final list = dates.values.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  @override
  Future<List<Devo>> search({String text = '', DateTime? date}) async {
    final query = text.trim().toLowerCase();
    final terms = query
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();
    final matches = catalog.devos.where((devo) {
      if (date != null && !isSameDate(devo.editionDate, date)) return false;
      if (terms.isEmpty) return true;
      final haystack = _haystack(devo);
      return terms.every(haystack.contains);
    });
    return devosInReadingOrder(matches);
  }

  String _haystack(Devo devo) {
    final labels = devo.tags.map(
      (slug) => catalog.tagBySlug(slug)?.label ?? slug,
    );
    return [
      devo.title,
      devo.hook,
      devo.bodyMd,
      devo.takeaway,
      devo.verseRef,
      devo.verseText,
      ...devo.tags,
      ...labels,
    ].join(' ').toLowerCase();
  }
}
