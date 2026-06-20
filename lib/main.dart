import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/storage_service.dart';
import 'models/user_config.dart';

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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: initialConfig == null
            ? const OnboardingScreen()
            : const HomeScreen(),
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
