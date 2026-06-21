import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/strings.dart';
import 'models/daily_session.dart';
import 'models/user_config.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final config = await StorageService.loadConfig();
  final locale = await StorageService.loadLocale();
  final cyclePosition = await StorageService.loadCyclePosition();
  final previewSession = await StorageService.loadPreviewSession();
  final todaySession = await StorageService.loadTodaySession();
  final pauseDates = await StorageService.loadPauseDates();
  S.locale = locale;
  runApp(QuranRevisionApp(
    initialConfig: config,
    initialCyclePosition: cyclePosition,
    initialPreviewSession: previewSession,
    initialTodaySession: todaySession,
    initialPauseDates: pauseDates,
  ));
}

class QuranRevisionApp extends StatelessWidget {
  final UserConfig? initialConfig;
  final int initialCyclePosition;
  final DailySession? initialPreviewSession;
  final DailySession? initialTodaySession;
  final Set<String> initialPauseDates;

  const QuranRevisionApp({
    super.key,
    this.initialConfig,
    this.initialCyclePosition = 0,
    this.initialPreviewSession,
    this.initialTodaySession,
    this.initialPauseDates = const {},
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        initialConfig,
        locale: S.locale,
        initialCyclePosition: initialCyclePosition,
        initialPreviewSession: initialPreviewSession,
        initialTodaySession: initialTodaySession,
        initialPauseDates: initialPauseDates,
      ),
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return MaterialApp(
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: state.config == null
          ? const OnboardingScreen()
          : const ShellScreen(),
    );
  }
}
