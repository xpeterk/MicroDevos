import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/devo.dart';
import '../../domain/models/devo_note.dart';
import '../../domain/models/tag.dart';

class BrowseFilter {
  const BrowseFilter({
    this.onlyLiked = false,
    this.onlyNotes = false,
    this.tags = const {},
    this.interests = const {},
    this.ageRange,
  });

  final bool onlyLiked;
  final bool onlyNotes;
  final Set<String> tags;
  final Set<String> interests;
  final String? ageRange;

  int get activeCount =>
      tags.length +
      interests.length +
      (onlyLiked ? 1 : 0) +
      (onlyNotes ? 1 : 0) +
      (ageRange == null ? 0 : 1);

  bool get hasChips =>
      tags.isNotEmpty || interests.isNotEmpty || ageRange != null;

  BrowseFilter copyWith({
    bool? onlyLiked,
    bool? onlyNotes,
    Set<String>? tags,
    Set<String>? interests,
    String? ageRange,
    bool clearAge = false,
  }) {
    return BrowseFilter(
      onlyLiked: onlyLiked ?? this.onlyLiked,
      onlyNotes: onlyNotes ?? this.onlyNotes,
      tags: tags ?? this.tags,
      interests: interests ?? this.interests,
      ageRange: clearAge ? null : ageRange ?? this.ageRange,
    );
  }
}

/// A selected filter matches the devotion or any of its sections when the
/// tag is on that row, or when a child of the selected tag is. The tag set
/// and the interest set both have to agree. Liked and notes do too. Age is
/// stored for the sheet and does not hide devotions yet.
List<Devo> applyBrowseFilter({
  required List<Devo> devos,
  required BrowseFilter filter,
  required Set<String> likedIds,
  required Set<String> notedIds,
  List<Tag> catalog = const [],
}) {
  final tags = expandTagSelection(filter.tags, catalog);
  final interests = expandTagSelection(filter.interests, catalog);
  return [
    for (final devo in devos)
      if (_matches(devo, filter, likedIds, notedIds, tags, interests)) devo,
  ];
}

bool _matches(
  Devo devo,
  BrowseFilter filter,
  Set<String> likedIds,
  Set<String> notedIds,
  Set<String> tags,
  Set<String> interests,
) {
  if (filter.onlyLiked && !likedIds.contains(devo.id)) return false;
  if (filter.onlyNotes && !notedIds.contains(devo.id)) return false;
  final slugs = <String>{
    ...devo.tags,
    for (final section in devo.sections) ...section.tags,
  };
  if (tags.isNotEmpty && !slugs.any(tags.contains)) return false;
  if (interests.isNotEmpty && !slugs.any(interests.contains)) return false;
  return true;
}

class BrowseFilterController extends Notifier<BrowseFilter> {
  @override
  BrowseFilter build() => const BrowseFilter();

  void setOnlyLiked(bool value) => state = state.copyWith(onlyLiked: value);

  void setOnlyNotes(bool value) => state = state.copyWith(onlyNotes: value);

  void toggleLiked() => setOnlyLiked(!state.onlyLiked);

  void toggleNotes() => setOnlyNotes(!state.onlyNotes);

  void addTag(String slug) {
    if (state.tags.contains(slug)) return;
    state = state.copyWith(tags: {...state.tags, slug});
  }

  void removeTag(String slug) {
    state = state.copyWith(tags: {...state.tags}..remove(slug));
  }

  void toggleInterest(String slug) {
    final next = {...state.interests};
    if (!next.add(slug)) next.remove(slug);
    state = state.copyWith(interests: next);
  }

  void removeInterest(String slug) {
    state = state.copyWith(interests: {...state.interests}..remove(slug));
  }

  void setAge(String? age) {
    state = age == null
        ? state.copyWith(clearAge: true)
        : state.copyWith(ageRange: age);
  }

  /// Drops tag, interest, and age chips. Liked and Notes stay as they are.
  void clearChips() {
    state = state.copyWith(tags: {}, interests: {}, clearAge: true);
  }

  void reset() => state = const BrowseFilter();
}

final browseFilterProvider =
    NotifierProvider<BrowseFilterController, BrowseFilter>(
      BrowseFilterController.new,
    );

enum PostDepth { collapsed, summary, full }

class PostDepthController extends Notifier<Map<String, PostDepth>> {
  @override
  Map<String, PostDepth> build() => const {};

  PostDepth depthOf(String id) => state[id] ?? PostDepth.collapsed;

  void setDepth(String id, PostDepth depth) {
    state = {...state, id: depth};
  }
}

final postDepthProvider =
    NotifierProvider<PostDepthController, Map<String, PostDepth>>(
      PostDepthController.new,
    );

class NoteDraft {
  const NoteDraft({
    required this.session,
    required this.devoId,
    required this.initialBody,
    this.noteId,
    this.anchorText,
    this.anchorStart,
    this.anchorEnd,
    this.section,
    this.sectionId,
    this.caption,
  });

  final String session;
  final String devoId;
  final String? noteId;
  final String initialBody;
  final String? anchorText;
  final int? anchorStart;
  final int? anchorEnd;
  final String? section;
  final String? sectionId;

  /// "Part 3 · Title — Parent" when the note is for one section.
  final String? caption;

  bool get hasAnchor => isUsableAnchor(anchorText);

  NoteDraft copyWith({
    String? anchorText,
    int? anchorStart,
    int? anchorEnd,
    String? section,
  }) {
    return NoteDraft(
      session: session,
      devoId: devoId,
      noteId: noteId,
      initialBody: initialBody,
      anchorText: anchorText ?? this.anchorText,
      anchorStart: anchorStart ?? this.anchorStart,
      anchorEnd: anchorEnd ?? this.anchorEnd,
      section: section ?? this.section,
      sectionId: sectionId,
      caption: caption,
    );
  }
}

class NoteDraftController extends Notifier<NoteDraft?> {
  @override
  NoteDraft? build() => null;

  void openNew(String devoId, {String? sectionId, String? caption}) {
    _open(
      NoteDraft(
        session: newNoteId(),
        devoId: devoId,
        initialBody: '',
        sectionId: sectionId,
        caption: caption,
      ),
    );
  }

  void openExisting(DevoNote note, {String? caption}) {
    final devoId = note.devoId ?? note.generatedDevoId;
    if (devoId == null) return;
    _open(
      NoteDraft(
        session: newNoteId(),
        devoId: devoId,
        noteId: note.id,
        initialBody: note.body,
        anchorText: note.anchorText,
        anchorStart: note.anchorStart,
        anchorEnd: note.anchorEnd,
        section: note.section,
        sectionId: note.sectionId,
        caption: caption,
      ),
    );
  }

  void _open(NoteDraft draft) {
    state = draft;
    ref.read(passageSelectionProvider.notifier).clear();
  }

  void close() {
    state = null;
    ref.read(passageSelectionProvider.notifier).clear();
  }

  void setAnchor({
    required String text,
    required String section,
    required int start,
    required int end,
  }) {
    final current = state;
    final trimmed = text.trim();
    if (current == null || !isUsableAnchor(trimmed)) return;
    state = current.copyWith(
      anchorText: trimmed,
      section: section,
      anchorStart: start,
      anchorEnd: start + trimmed.length,
    );
  }
}

final noteDraftProvider = NotifierProvider<NoteDraftController, NoteDraft?>(
  NoteDraftController.new,
);

class PassageSelection {
  const PassageSelection({required this.text, required this.section});

  final String text;
  final String section;
}

class PassageSelectionController extends Notifier<PassageSelection?> {
  @override
  PassageSelection? build() => null;

  void setText(String? text) {
    final trimmed = text?.trim() ?? '';
    if (!isUsableAnchor(trimmed)) {
      state = null;
      return;
    }
    if (state?.text == trimmed) return;
    state = PassageSelection(text: trimmed, section: '');
  }

  void clear() => state = null;
}

final passageSelectionProvider =
    NotifierProvider<PassageSelectionController, PassageSelection?>(
      PassageSelectionController.new,
    );

enum SavedSegment { liked, notes, mine }

class SavedSegmentController extends Notifier<SavedSegment> {
  @override
  SavedSegment build() => SavedSegment.liked;

  void show(SavedSegment segment) {
    state = segment == SavedSegment.mine ? SavedSegment.liked : segment;
  }
}

final savedSegmentProvider =
    NotifierProvider<SavedSegmentController, SavedSegment>(
      SavedSegmentController.new,
    );

const ageRangeChoices = ['Teen', '18–29', '30–44', '45–64', '65+'];
