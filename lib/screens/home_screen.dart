import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/hadith_data.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/riwaya.dart';
import '../services/ayah_facts_service.dart';
import '../state/app_state.dart';
import '../widgets/cycle_progress_card.dart';
import '../widgets/hadith_card.dart';
import '../widgets/ornamental_divider.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/spotlight_tour.dart';

/// État "au repos" de l'onglet Plan du jour : ce qui donne envie d'ouvrir sa
/// journée (progression de cycle, streak, hadith) et le point d'entrée
/// unique du rituel quotidien — « Illuminer ma journée avec le Coran ».
/// Depuis la Phase 9, le choix des prières a quitté cet écran pour le
/// check-in ([CheckInScreen]) : rythme, apprentissage et prières se
/// confirment au même endroit, juste avant que le plan ne soit réparti.
class HomeScreen extends StatefulWidget {
  final VoidCallback onIlluminer;
  final VoidCallback? onSaisirManuel;

  const HomeScreen({super.key, required this.onIlluminer, this.onSaisirManuel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _streak = 0;
  Riwaya? _lastRiwaya;
  DaySelection? _daySelection;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies tourne une première fois juste après initState
    // (couvre le chargement initial), puis à chaque fois qu'AppState notifie
    // — HomeScreen reste monté (IndexedStack de ShellScreen) le temps d'un
    // changement de riwaya, donc on recharge le streak du parcours
    // nouvellement actif au lieu de garder celui de l'ancien.
    final riwaya = context.read<AppState>().riwaya;
    if (riwaya != _lastRiwaya) {
      _lastRiwaya = riwaya;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final state = context.read<AppState>();
    // Lectures indépendantes démarrées en parallèle — un seul aller-retour
    // au lieu de plusieurs en série (même principe qu'ailleurs, voir
    // recap_screen.dart._load).
    final streakF = AyahFactsService.currentStreak(
        pauseDates: state.pauseDates, riwaya: state.riwaya);
    final daySelectionF = state.getDaySelectionForToday();
    final streak = await streakF;
    final daySelection = await daySelectionF;
    if (!mounted) return;
    setState(() {
      _streak = streak;
      _daySelection = daySelection;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // Pas de floating : SliverAppBar.large afficherait le titre deux fois
          // pendant l'animation de repli si floating était activé.
          SliverAppBar(
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            toolbarHeight: 0,
            elevation: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Center(
                  child: Text(S.homeEpigraph,
                      style: GoogleFonts.amiri(fontSize: 15, color: palette.gold)),
                ).animate().fadeIn(),
                const SizedBox(height: 10),
                Text(S.reviserAujourdhui,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary)),
                const SizedBox(height: 10),
                const Center(child: OrnamentalDivider(lineWidth: 26)),
                const SizedBox(height: 18),
                CycleProgressCard(
                  progress: (_daySelection?.cycleTotal ?? 0) > 0
                      ? _daySelection!.cyclePosition / _daySelection!.cycleTotal
                      : 0.0,
                  pos: _daySelection?.cyclePosition ?? 0,
                  total: _daySelection?.cycleTotal ?? 0,
                  streak: _streak,
                ),
                const SizedBox(height: 16),
                HadithCard(hadith: hadithDuJour(DateTime.now())),
                const SizedBox(height: 28),
                KeyedSubtree(
                  key: TourKeys.voirPlanButton,
                  child: PrimaryCtaButton(
                    onPressed: widget.onIlluminer,
                    icon: Icons.wb_sunny_outlined,
                    label: S.illuminerMaJournee,
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
                const SizedBox(height: 8),
                Center(
                  child: Text(S.illuminerSousTitre,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: palette.textMuted)),
                ).animate().fadeIn(delay: 300.ms),
                if (widget.onSaisirManuel != null)
                  TextButton(
                    onPressed: widget.onSaisirManuel,
                    child: Text(S.saisirManuellement),
                  ).animate().fadeIn(delay: 350.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
