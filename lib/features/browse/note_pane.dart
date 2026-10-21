import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/devo_note.dart';
import 'browse_state.dart';
import 'passage.dart';

class NotePane extends ConsumerStatefulWidget {
  const NotePane({super.key});

  @override
  ConsumerState<NotePane> createState() => _NotePaneState();
}

class _NotePaneState extends ConsumerState<NotePane> {
  late final TextEditingController _body;

  @override
  void initState() {
    super.initState();
    _body = TextEditingController(
      text: ref.read(noteDraftProvider)?.initialBody ?? '',
    );
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _done() async {
    final draft = ref.read(noteDraftProvider);
    if (draft == null) return;
    final text = _body.text.trim();
    if (text.isEmpty) {
      ref.read(noteDraftProvider.notifier).close();
      return;
    }
    final now = DateTime.now().toUtc();
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(notesProvider.notifier)
        .save(
          DevoNote(
            id: draft.noteId ?? '',
            devoId: draft.devoId,
            body: text,
            anchorText: draft.anchorText,
            anchorStart: draft.anchorStart,
            anchorEnd: draft.anchorEnd,
            section: draft.hasAnchor ? draft.section : null,
            sectionId: draft.sectionId,
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1800),
          backgroundColor: Color(0xFF2C382F),
          content: Text(
            'Note saved · Saved › Notes',
            style: TextStyle(fontFamily: AppTheme.sans, color: Colors.white),
          ),
        ),
      );
    ref.read(noteDraftProvider.notifier).close();
  }

  Future<void> _trash() async {
    final id = ref.read(noteDraftProvider)?.noteId;
    if (id != null) await ref.read(notesProvider.notifier).delete(id);
    if (!mounted) return;
    ref.read(noteDraftProvider.notifier).close();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(noteDraftProvider);
    if (draft == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const Key('note-editor'),
      color: const Color(0xFFF8E7A2),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (draft.caption != null && draft.caption!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  draft.caption!,
                  key: const Key('note-section-caption'),
                  style: const TextStyle(
                    fontFamily: AppTheme.sans,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3A2A1C),
                  ),
                ),
              ),
            Row(
              children: [
                const Icon(Icons.sticky_note_2_outlined, size: 18),
                const SizedBox(width: 6),
                Text(
                  'My note',
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontFamily: AppTheme.sans),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Delete note',
                  onPressed: _trash,
                  icon: const Icon(Icons.delete_outline),
                ),
                FilledButton(
                  key: const Key('note-done'),
                  onPressed: _done,
                  child: const Text('Done'),
                ),
              ],
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF6CC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: draft.hasAnchor
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ANCHORED TO',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                fontFamily: AppTheme.sans,
                                letterSpacing: 1,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '“${draft.anchorText}”',
                          key: const Key('anchor-preview'),
                          style: const TextStyle(
                            fontFamily: AppTheme.serif,
                            fontStyle: FontStyle.italic,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Select a passage in the devo to anchor this note.',
                      style: TextStyle(fontFamily: AppTheme.sans, fontSize: 14),
                    ),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('note-body'),
              controller: _body,
              minLines: 2,
              maxLines: 4,
              style: const TextStyle(fontFamily: AppTheme.serif, fontSize: 16),
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Write a private note',
                border: InputBorder.none,
              ),
            ),
            Text(
              'Private to you · saved with this devo',
              style: TextStyle(
                fontFamily: AppTheme.sans,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnchorToolbar extends ConsumerWidget {
  const AnchorToolbar({required this.devoId, super.key});

  final String devoId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(passageSelectionProvider);
    if (selection == null) return const SizedBox.shrink();
    return Material(
      color: const Color(0xFF243028),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            key: const Key('anchor-note'),
            onPressed: () {
              final today = ref.read(todayProvider).asData?.value;
              final devo =
                  today?.devos.where((item) => item.id == devoId).firstOrNull ??
                  ref.read(devoByIdProvider(devoId)).asData?.value;
              if (devo == null) return;
              final text = selection.text.trim();
              if (!isUsableAnchor(text)) return;
              final spot = locatePassage(devo, text);
              if (spot == null) return;
              ref
                  .read(noteDraftProvider.notifier)
                  .setAnchor(
                    text: text,
                    section: spot.section,
                    start: spot.start,
                    end: spot.start + text.length,
                  );
              ref.read(passageSelectionProvider.notifier).clear();
            },
            icon: const Icon(Icons.anchor, color: Colors.white, size: 16),
            label: const Text(
              'Anchor note',
              style: TextStyle(color: Colors.white, fontFamily: AppTheme.sans),
            ),
          ),
          Container(width: 1, height: 16, color: Colors.white24),
          TextButton(
            key: const Key('copy-selection'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: selection.text));
              ref.read(passageSelectionProvider.notifier).clear();
            },
            child: const Text(
              'Copy',
              style: TextStyle(color: Colors.white, fontFamily: AppTheme.sans),
            ),
          ),
        ],
      ),
    );
  }
}
