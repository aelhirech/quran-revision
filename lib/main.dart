import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/strings.dart';
import 'models/daily_session.dart';
import 'models/riwaya.dart';
import 'models/user_config.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/warsh_service.dart';
import 'state/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  // Ne doit jamais bloquer le démarrage : si l'asset Warsh échoue à charger
  // (corruption, hoquet réseau sur le premier chargement web), l'app démarre
  // quand même en Hafs plutôt que de rester bloquée sur un écran blanc.
  try {
    await WarshService.initialize();
  } catch (_) {}
  final config = await StorageService.loadConfig();
  final locale = await StorageService.loadLocale();
  final riwaya = await StorageService.loadRiwaya();
  final cyclePosition = await StorageService.loadCyclePosition();
  final previewSession = await StorageService.loadPreviewSession();
  final todaySession = await StorageService.loadTodaySession();
  final pauseDates = await StorageService.loadPauseDates();
  // Si la session du jour est absente (jamais engagée ou stale), les cases
  // cochées persistées ne peuvent correspondre à aucun plan valide.
  final checkedRakaas = todaySession == null
      ? <int, Set<int>>{}
      : await StorageService.loadCheckedRakaas();
  S.locale = locale;
  runApp(QuranRevisionApp(
    initialConfig: config,
    initialRiwaya: riwaya,
    initialCyclePosition: cyclePosition,
    initialPreviewSession: previewSession,
    initialTodaySession: todaySession,
    initialPauseDates: pauseDates,
    initialCheckedRakaas: checkedRakaas,
  ));
}

class QuranRevisionApp extends StatelessWidget {
  final UserConfig? initialConfig;
  final Riwaya initialRiwaya;
  final int initialCyclePosition;
  final DailySession? initialPreviewSession;
  final DailySession? initialTodaySession;
  final Set<String> initialPauseDates;
  final Map<int, Set<int>> initialCheckedRakaas;

  const QuranRevisionApp({
    super.key,
    this.initialConfig,
    this.initialRiwaya = Riwaya.hafs,
    this.initialCyclePosition = 0,
    this.initialPreviewSession,
    this.initialTodaySession,
    this.initialPauseDates = const {},
    this.initialCheckedRakaas = const {},
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        initialConfig,
        locale: S.locale,
        riwaya: initialRiwaya,
        initialCyclePosition: initialCyclePosition,
        initialPreviewSession: initialPreviewSession,
        initialTodaySession: initialTodaySession,
        initialPauseDates: initialPauseDates,
        initialCheckedRakaas: initialCheckedRakaas,
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
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: state.config == null
          ? const OnboardingScreen()
          : const ShellScreen(),
    );
  }
}
