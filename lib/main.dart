import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_theme.dart';
import 'core/strings.dart';
import 'models/riwaya.dart';
import 'models/user_config.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/hafs_service.dart';
import 'services/hizb_metadata_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/surah_metadata_service.dart';
import 'services/warsh_service.dart';
import 'state/app_state.dart';

/// Ne doit jamais bloquer le démarrage : si l'asset Warsh échoue à charger
/// (corruption, hoquet réseau sur le premier chargement web), l'app démarre
/// quand même en Hafs plutôt que de rester bloquée sur un écran blanc.
Future<bool> _initWarsh() async {
  try {
    await WarshService.initialize();
    return true;
  } catch (_) {
    return false;
  }
}

/// Purement cosmétique (regroupement par Hizb dans l'onboarding) — un échec
/// ne doit jamais empêcher l'app de démarrer, contrairement à Hafs qui est
/// indispensable partout et ne peut pas dégrader proprement.
Future<void> _initHizb() async {
  try {
    await HizbMetadataService.initialize();
  } catch (_) {
    // HizbMetadataService.surahStartHizb retombe sur {} si jamais initialisé.
  }
}

/// Purement cosmétique (affichage de la Bismillah) — même garde qu'`_initHizb`.
Future<void> _initSurahMeta() async {
  try {
    await SurahMetadataService.initialize();
  } catch (_) {
    // SurahMetadataService.bismillahPre retombe sur false si jamais initialisé.
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  // Chargements d'assets indépendants — démarrés en parallèle.
  final hafsF = HafsService.initialize();
  final hizbF = _initHizb();
  final surahMetaF = _initSurahMeta();
  final warshAvailableF = _initWarsh();
  await hafsF;
  await hizbF;
  await surahMetaF;
  final warshAvailable = await warshAvailableF;

  // Migration one-shot des installations pré-parcours-par-riwaya (config,
  // cycle, pauses) vers le parcours Hafs — doit tourner avant toute lecture
  // ci-dessous.
  await StorageService.migrateLegacyTrackData();

  // La riwaya active doit être connue avant de charger le reste : chaque
  // parcours (Hafs/Warsh) a sa propre config/cycle/sessions/pauses. Si le
  // texte Warsh n'a pas pu être chargé, on ignore la riwaya persistée pour
  // éviter un crash au premier rendu de verset.
  final riwaya = warshAvailable ? await StorageService.loadRiwaya() : Riwaya.hafs;

  // Lectures indépendantes démarrées en parallèle — un seul aller-retour
  // au lieu de plusieurs en série avant le premier frame.
  final configF = StorageService.loadConfig(riwaya);
  final localeF = StorageService.loadLocale();
  final cyclePositionF = StorageService.loadCyclePosition(riwaya);
  final pauseDatesF = StorageService.loadPauseDates(riwaya);
  final hasSeenTourF = StorageService.hasSeenTour();

  final config = await configF;
  final locale = await localeF;
  final cyclePosition = await cyclePositionF;
  final pauseDates = await pauseDatesF;
  final hasSeenTour = await hasSeenTourF;
  S.locale = locale;
  runApp(QuranRevisionApp(
    initialConfig: config,
    initialRiwaya: riwaya,
    warshAvailable: warshAvailable,
    initialCyclePosition: cyclePosition,
    initialPauseDates: pauseDates,
    initialHasSeenTour: hasSeenTour,
  ));
}

class QuranRevisionApp extends StatelessWidget {
  final UserConfig? initialConfig;
  final Riwaya initialRiwaya;
  final bool warshAvailable;
  final int initialCyclePosition;
  final Set<String> initialPauseDates;
  final bool initialHasSeenTour;

  const QuranRevisionApp({
    super.key,
    this.initialConfig,
    this.initialRiwaya = Riwaya.hafs,
    this.warshAvailable = true,
    this.initialCyclePosition = 0,
    this.initialPauseDates = const {},
    this.initialHasSeenTour = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        initialConfig,
        locale: S.locale,
        riwaya: initialRiwaya,
        warshAvailable: warshAvailable,
        initialHasSeenTour: initialHasSeenTour,
        initialCyclePosition: initialCyclePosition,
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
      theme: buildAppTheme(Brightness.light),
      darkTheme: buildAppTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: state.config == null
          // `hasSeenTour` sert de proxy à "a déjà terminé l'onboarding au
          // moins une fois" : si oui, on arrive ici parce que l'utilisateur
          // vient de basculer vers un parcours (riwaya) jamais configuré —
          // l'onboarding saute directement à la sélection des sourates. Lu
          // depuis AppState (réactif) plutôt que figé au boot, pour rester
          // correct si le tour est vu puis la riwaya changée dans la même
          // session.
          ? OnboardingScreen(
              presetRiwaya: state.hasSeenTour ? state.riwaya : null,
            )
          : const ShellScreen(),
    );
  }
}
