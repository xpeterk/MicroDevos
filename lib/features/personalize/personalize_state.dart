import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/supabase/generate_devo_client.dart';
import '../../domain/models/generated_devo.dart';
import '../../domain/personalize/personalize_engine.dart';

enum PersonalizeSource { topic, verse }

class PersonalizeForm {
  const PersonalizeForm({
    this.source = PersonalizeSource.topic,
    this.topic = '',
    this.verseRefs = const [],
    this.ageRange,
    this.lifeSituations = const [],
    this.suggestion,
    this.styleKey = 'purpose',
    this.step = 0,
  });

  final PersonalizeSource source;
  final String topic;
  final List<String> verseRefs;
  final String? ageRange;
  final List<String> lifeSituations;
  final String? suggestion;
  final String styleKey;
  final int step;

  bool get verseMode => source == PersonalizeSource.verse;

  bool get canContinue {
    if (verseMode) return verseRefs.isNotEmpty;
    return topic.trim().isNotEmpty || (suggestion?.trim().isNotEmpty ?? false);
  }

  String get promptTopic {
    final typed = topic.trim();
    if (typed.isNotEmpty) return typed;
    return suggestion?.trim() ?? '';
  }

  PersonalizeForm copyWith({
    PersonalizeSource? source,
    String? topic,
    List<String>? verseRefs,
    String? ageRange,
    List<String>? lifeSituations,
    String? suggestion,
    String? styleKey,
    int? step,
    bool clearAge = false,
    bool clearSuggestion = false,
  }) {
    return PersonalizeForm(
      source: source ?? this.source,
      topic: topic ?? this.topic,
      verseRefs: verseRefs ?? this.verseRefs,
      ageRange: clearAge ? null : ageRange ?? this.ageRange,
      lifeSituations: lifeSituations ?? this.lifeSituations,
      suggestion: clearSuggestion ? null : suggestion ?? this.suggestion,
      styleKey: styleKey ?? this.styleKey,
      step: step ?? this.step,
    );
  }

  GenerateRequest toRequest({bool regenerate = false, String? bibleVersion}) {
    return GenerateRequest(
      verseMode: verseMode,
      topic: promptTopic,
      verseRefs: verseRefs,
      styleKey: styleKey,
      ageRange: ageRange,
      lifeSituations: lifeSituations,
      bibleVersion: bibleVersion,
      regenerate: regenerate,
    );
  }
}

class PersonalizeFormController extends Notifier<PersonalizeForm> {
  @override
  PersonalizeForm build() => const PersonalizeForm();

  void reset() => state = const PersonalizeForm();

  void setSource(PersonalizeSource source) =>
      state = state.copyWith(source: source);

  void setTopic(String topic) => state = state.copyWith(topic: topic);

  void addVerse(String reference) {
    final trimmed = reference.trim();
    if (trimmed.isEmpty || state.verseRefs.contains(trimmed)) return;
    state = state.copyWith(verseRefs: [...state.verseRefs, trimmed]);
  }

  void removeVerse(String reference) {
    state = state.copyWith(
      verseRefs: [
        for (final ref in state.verseRefs)
          if (ref != reference) ref,
      ],
    );
  }

  void setAge(String? age) {
    state = state.ageRange == age
        ? state.copyWith(clearAge: true)
        : state.copyWith(ageRange: age);
  }

  void toggleLife(String label) {
    final next = [...state.lifeSituations];
    if (!next.remove(label)) next.add(label);
    state = state.copyWith(lifeSituations: next);
  }

  void toggleSuggestion(String label) {
    if (state.suggestion == label) {
      state = state.copyWith(clearSuggestion: true);
      return;
    }
    state = state.copyWith(suggestion: label);
  }

  void setStyle(String key) => state = state.copyWith(styleKey: key);

  void setStep(int step) => state = state.copyWith(step: step);
}

final personalizeFormProvider =
    NotifierProvider<PersonalizeFormController, PersonalizeForm>(
      PersonalizeFormController.new,
    );

class ShowCreateHintController extends Notifier<bool> {
  @override
  bool build() => false;

  void show() => state = true;

  void hide() => state = false;
}

final showCreateHintProvider = NotifierProvider<ShowCreateHintController, bool>(
  ShowCreateHintController.new,
);

/// How long the writing screen stays up. Widget tests advance this with pump.
final personalizePaceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 900),
);

final personalizeEngineProvider = Provider<PersonalizeEngine>((ref) {
  return PersonalizeEngine(
    config: const GenerationCapConfig(),
    clock: () => ref.read(clockProvider)(),
  );
});

class PersonalizeGateway {
  const PersonalizeGateway({required this.engine, this.remote});

  final PersonalizeEngine engine;
  final Future<Object> Function(GenerateRequest request)? remote;

  Future<Object> generate(GenerateRequest request) {
    final call = remote;
    if (call != null) return call(request);
    return engine.generate(request);
  }
}

final personalizeGatewayProvider = Provider<PersonalizeGateway>((ref) {
  final engine = ref.watch(personalizeEngineProvider);
  final client = ref.watch(supabaseClientProvider);
  final signedIn = client?.auth.currentUser != null;
  return PersonalizeGateway(
    engine: engine,
    remote: client != null && signedIn
        ? GenerateDevoClient(client).generate
        : null,
  );
});

class PersonalizeRun {
  const PersonalizeRun({
    this.devo,
    this.request,
    this.blockedReason,
    this.writing = false,
  });

  final GeneratedDevo? devo;
  final GenerateRequest? request;
  final String? blockedReason;
  final bool writing;
}

class PersonalizeRunController extends Notifier<PersonalizeRun> {
  @override
  PersonalizeRun build() => const PersonalizeRun();

  void dismiss() => state = const PersonalizeRun();

  Future<void> start(GenerateRequest request) async {
    state = PersonalizeRun(writing: true, request: request);
    await Future<void>.delayed(ref.read(personalizePaceProvider));
    final result = await ref.read(personalizeGatewayProvider).generate(request);
    if (result is GenerateBlocked) {
      state = PersonalizeRun(
        request: request,
        blockedReason: result.cap.reason ?? 'Generation is not available',
      );
      return;
    }
    if (result is GenerateRejected) {
      state = PersonalizeRun(request: request, blockedReason: result.reason);
      return;
    }
    final ok = result as GenerateOk;
    state = PersonalizeRun(devo: ok.devo, request: request);
  }

  Future<void> regenerate() {
    final request = state.request;
    if (request == null) return Future.value();
    return start(request.copyWith(regenerate: true));
  }
}

final personalizeRunProvider =
    NotifierProvider<PersonalizeRunController, PersonalizeRun>(
      PersonalizeRunController.new,
    );

class MineController extends AsyncNotifier<List<GeneratedDevo>> {
  static const _key = 'mine_devos';

  @override
  Future<List<GeneratedDevo>> build() async {
    final raw = ref.watch(sharedPreferencesProvider).getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map)
          GeneratedDevo.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  Future<void> save(GeneratedDevo devo) async {
    final current = [...state.value ?? await future];
    final next = [
      for (final item in current)
        if (item.id != devo.id) item,
      devo,
    ];
    state = AsyncData(next);
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode(next.map((item) => item.toJson()).toList()),
        );
  }

  Future<void> replaceAll(List<GeneratedDevo> devos) async {
    state = AsyncData(devos);
    await ref
        .read(sharedPreferencesProvider)
        .setString(
          _key,
          jsonEncode(devos.map((item) => item.toJson()).toList()),
        );
  }
}

final mineProvider = AsyncNotifierProvider<MineController, List<GeneratedDevo>>(
  MineController.new,
);
