import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/app_config.dart';
import 'theme/app_theme.dart';

/// Loads locale data and installs an error screen before [runApp].
///
/// Date labels use intl. en_US has built-in symbols; every other locale
/// throws [LocaleDataException] until this runs, and release paints that
/// as a grey box. The app copy is English, so the locale is pinned too.
/// Portrait and landscape, including upside down. Nothing in the app locks
/// the phone to portrait.
const supportedOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

Future<void> prepareFramework() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'en_US';
  await initializeDateFormatting('en_US');
  installReadableErrorWidget();
  // Do not await. A widget test that awaits this platform call before the
  // first pump never receives the reply, and the test hangs.
  unawaited(SystemChrome.setPreferredOrientations(supportedOrientations));
}

/// Replaces Flutter's release error box (an empty grey rectangle) with copy
/// on the paper background.
void installReadableErrorWidget() {
  ErrorWidget.builder = (details) {
    return ColoredBox(
      key: const Key('readable-error'),
      color: AppColors.paper,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            kDebugMode
                ? 'This screen could not be drawn.\n${details.exceptionAsString()}'
                : 'This screen could not be drawn.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 18,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  };
}

/// Returns a client only when [AppConfig.useSupabase] is true and init works.
///
/// An empty or rejected URL must not throw out of `main`. The Android window
/// would stay on the launch color (`#F6F1E8`) because [runApp] never runs.
Future<SupabaseClient?> openSupabaseClient(AppConfig config) async {
  if (!config.useSupabase) return null;
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
    return Supabase.instance.client;
  } on Object catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'startup',
        context: ErrorDescription(
          'while starting Supabase; falling back to sample devotions',
        ),
      ),
    );
    return null;
  }
}
