import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';
import 'services/storage_service.dart';
import 'models/user_config.dart';

ThemeData _buildTheme() {
  const green = Color(0xFF1A5C38);
  const greenLight = Color(0xFF2E7D52);
  const bg = Color(0xFFF7F8F5);

  final base = ColorScheme.fromSeed(
    seedColor: green,
    brightness: Brightness.light,
  ).copyWith(
    primary: green,
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFE8F5EE),
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
    cardTheme: CardTheme(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      shadowColor: Colors.black.withOpacity(0.06),
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
      shadowColor: Colors.black.withOpacity(0.08),
      indicatorColor: const Color(0xFFE8F5EE),
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
      selectedColor: const Color(0xFFE8F5EE),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide.none,
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await StorageService.loadConfig();
  runApp(QuranRevisionApp(initialConfig: config));
}

class QuranRevisionApp extends StatelessWidget {
  final UserConfig? initialConfig;

  const QuranRevisionApp({super.key, this.initialConfig});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(initialConfig),
      child: MaterialApp(
        title: 'Révision Coran',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: initialConfig == null
            ? const OnboardingScreen()
            : const ShellScreen(),
      ),
    );
  }
}

class AppState extends ChangeNotifier {
  UserConfig? _config;
  int _cyclePosition = 0;

  AppState(this._config) {
    _loadCyclePosition();
  }

  UserConfig? get config => _config;
  int get cyclePosition => _cyclePosition;

  Future<void> _loadCyclePosition() async {
    _cyclePosition = await StorageService.loadCyclePosition();
    notifyListeners();
  }

  Future<void> saveConfig(UserConfig config) async {
    _config = config;
    _cyclePosition = 0;
    await StorageService.saveConfig(config);
    await StorageService.saveCyclePosition(0);
    notifyListeners();
  }

  Future<void> advanceCycle(int unitsCompleted, int cycleTotal) async {
    _cyclePosition = (_cyclePosition + unitsCompleted) % cycleTotal;
    await StorageService.saveCyclePosition(_cyclePosition);
    notifyListeners();
  }
}
