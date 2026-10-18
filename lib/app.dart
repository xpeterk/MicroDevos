import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class MicroDevosApp extends ConsumerStatefulWidget {
  const MicroDevosApp({super.key});

  @override
  ConsumerState<MicroDevosApp> createState() => _MicroDevosAppState();
}

class _MicroDevosAppState extends ConsumerState<MicroDevosApp> {
  late final _router = buildRouter();
  UserPreferencesSnapshot? _lastSynced;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    ref.listen(preferencesProvider, (previous, next) {
      final value = next.value;
      if (value == null) return;
      final snapshot = UserPreferencesSnapshot(value.notifyTimeLabel, value.notificationsEnabled);
      if (snapshot == _lastSynced) return;
      _lastSynced = snapshot;
      ref.read(reminderServiceProvider).sync(value);
    });
    return MaterialApp.router(
      title: 'Micro Devos',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class UserPreferencesSnapshot {
  const UserPreferencesSnapshot(this.time, this.enabled);

  final String time;
  final bool enabled;

  @override
  bool operator ==(Object other) {
    return other is UserPreferencesSnapshot &&
        other.time == time &&
        other.enabled == enabled;
  }

  @override
  int get hashCode => Object.hash(time, enabled);
}
