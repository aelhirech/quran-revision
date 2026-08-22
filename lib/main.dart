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
  var warshAvailable = true;
  try {
    await WarshService.initialize();
  } catch (_) {
    warshAvailable = false;
  }
  // Lectures indépendantes démarrées en parallèle — un seul aller-retour
  // au lieu de 7 en série avant le premier frame.
  final configF = StorageService.loadConfig();
  final localeF = StorageService.loadLocale();
  final riwayaF = warshAvailable ? StorageService.loadRiwaya() : null;
  final cyclePositionF = StorageService.loadCyclePosition();
  final previewSessionF = StorageService.loadPreviewSession();
  final todaySessionF = StorageService.loadTodaySession();
  final pauseDatesF = StorageService.loadPauseDates();
  // loadCheckedRakaas purge elle-même la clé si sa date ne correspond plus
  // à aujourd'hui — pas besoin de dupliquer cette vérification ici.
  final checkedRakaasF = StorageService.loadCheckedRakaas();

  final config = await configF;
  final locale = await localeF;
  // Si le texte Warsh n'a pas pu être chargé, on ignore la riwaya persistée
  // pour éviter un crash au premier rendu de verset (WarshService.getVerse
  // lève sinon une exception faute de données).
  final riwaya = riwayaF == null ? Riwaya.hafs : await riwayaF;
  final cyclePosition = await cyclePositionF;
  final previewSession = await previewSessionF;
  final todaySession = await todaySessionF;
  final pauseDates = await pauseDatesF;
  final checkedRakaas = await checkedRakaasF;
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
