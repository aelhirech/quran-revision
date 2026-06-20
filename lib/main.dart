import 'package:flutter/material.dart';
import 'core/app_colors.dart';
import 'package:provider/provider.dart';
import 'core/strings.dart';
import 'models/daily_session.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'models/user_config.dart';

ThemeData _buildTheme() {
  const green = AppColors.green;
  const greenLight = AppColors.greenLight;
  const bg = AppColors.bg;

  final base = ColorScheme.fromSeed(
    seedColor: green,
    brightness: Brightness.light,
  ).copyWith(
    primary: green,
    onPrimary: Colors.white,
    primaryContainer: AppColors.greenContainer,
    onPrimaryContainer: green,
    secondary: greenLight,
    surface: Colors.white,
    onSurface: const Color(0xFF111311),
    surfaceContainerHighest: bg,
    onSurfaceVariant: const Color(0xFF4A5450),
  );

  return ThemeData(
    colorScheme: base,
    useMaterial3: true,
    scaffoldBackgroundColor: bg,
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black.withValues(alpha: 0.06),
      surfaceTintColor: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Color(0xFF111311),
      titleTextStyle: TextStyle(
        color: Color(0xFF111311),
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      indicatorColor: AppColors.greenContainer,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        elevation: 0,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: bg,
      selectedColor: AppColors.greenContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  final config = await StorageService.loadConfig();
  final locale = await StorageService.loadLocale();
  final cyclePosition = await StorageService.loadCyclePosition();
  S.locale = locale;
  runApp(QuranRevisionApp(
    initialConfig: config,
    initialCyclePosition: cyclePosition,
  ));
}

class QuranRevisionApp extends StatelessWidget {
  final UserConfig? initialConfig;
  final int initialCyclePosition;

  const QuranRevisionApp({
    super.key,
    this.initialConfig,
    this.initialCyclePosition = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(
        initialConfig,
        locale: S.locale,
        initialCyclePosition: initialCyclePosition,
      ),
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    // Watch AppState so all descendants rebuild when locale changes
    final state = context.watch<AppState>();
    return MaterialApp(
      title: S.appTitle,
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: state.config == null
          ? const OnboardingScreen()
          : const ShellScreen(),
    );
  }
}

class AppState extends ChangeNotifier {
  UserConfig? _config;
  int _cyclePosition;
  DailySession? _previewSession;
  DailySession? _todaySession;
  String _locale;

  AppState(
    this._config, {
    String locale = 'fr',
    int initialCyclePosition = 0,
  })  : _locale = locale,
        _cyclePosition = initialCyclePosition;

  UserConfig? get config => _config;
  int get cyclePosition => _cyclePosition;
  DailySession? get previewSession => _previewSession;
  DailySession? get todaySession => _todaySession;
  String get locale => _locale;

  void setLocale(String locale) {
    _locale = locale;
    S.locale = locale;
    notifyListeners();
  }

  Future<void> saveConfig(UserConfig config) async {
    _config = config;
    _cyclePosition = 0;
    _todaySession = null;
    await StorageService.saveConfig(config);
    await StorageService.saveCyclePosition(0);
    notifyListeners();
  }

  Future<void> advanceCycle(int unitsCompleted, int cycleTotal) async {
    if (cycleTotal == 0) return;
    _cyclePosition = (_cyclePosition + unitsCompleted) % cycleTotal;
    await StorageService.saveCyclePosition(_cyclePosition);
    notifyListeners();
  }

  void setPreviewSession(DailySession session) {
    _previewSession = session;
    notifyListeners();
  }

  void engager() {
    _todaySession = _previewSession;
    _previewSession = null;
    notifyListeners();
  }

  void clearPreview() {
    _previewSession = null;
    notifyListeners();
  }

  void clearTodaySession() {
    _todaySession = null;
    _previewSession = null;
    notifyListeners();
  }
}


