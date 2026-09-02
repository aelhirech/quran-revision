import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/hadith_data.dart';
import '../core/strings.dart';
import '../models/prayer.dart';
import '../models/riwaya.dart';
import '../services/ayah_facts_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import '../widgets/cycle_progress_card.dart';
import '../widgets/hadith_card.dart';
import '../widgets/ornamental_divider.dart';
import '../widgets/prayer_selector.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/spotlight_tour.dart';

class HomeScreen extends StatefulWidget {
  final void Function(List<Prayer> prayersAlone) onVoirPlan;
  final VoidCallback? onSaisirManuel;

  const HomeScreen({super.key, required this.onVoirPlan, this.onSaisirManuel});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<Prayer> _prayersAlone = {};
  int _tahiyyatCount = 0;
  int _streak = 0;
  List<Prayer>? _lastPrayers;
  bool _isYesterday = false;
  Riwaya? _lastRiwaya;

  /// Liste effective : prières sélectionnées + tahiyyatMasjid répété n fois.
  /// Les doublons sont intentionnels — chaque entrée à la mosquée est une prière séparée.
  List<Prayer> get _effectivePrayers => [
        ...Prayer.values.where((p) => !p.isTahiyyat && _prayersAlone.contains(p)),
        for (int i = 0; i < _tahiyyatCount; i++) Prayer.tahiyyatMasjid,
      ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies tourne une première fois juste après initState
    // (couvre le chargement initial), puis à chaque fois qu'AppState notifie
    // — HomeScreen reste monté (IndexedStack de ShellScreen) le temps d'un
    // changement de riwaya, donc on recharge le streak/dernière session du
    // parcours nouvellement actif au lieu de garder ceux de l'ancien.
    final riwaya = context.read<AppState>().riwaya;
    if (riwaya != _lastRiwaya) {
      _lastRiwaya = riwaya;
      _loadHistory();
    }
  }

  Future<void> _loadHistory() async {
    final state = context.read<AppState>();
    final streak = await AyahFactsService.currentStreak(
        pauseDates: state.pauseDates, riwaya: state.riwaya);
    final last = await StorageService.loadLastSessionPrayers(state.riwaya);
    if (!mounted) return;

    List<Prayer>? lastPrayers;
    bool isYesterday = false;
    if (last != null && last.prayers.isNotEmpty) {
      lastPrayers = last.prayers;
      final lastDate = last.date.toIso8601String().substring(0, 10);
      final yesterday = DateTime.now()
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      isYesterday = lastDate == yesterday;
    }
    setState(() {
      _streak = streak;
      _lastPrayers = lastPrayers;
      _isYesterday = isYesterday;
    });
  }

  void _applyLastPrayers() {
    if (_lastPrayers == null) return;
    // tahiyyatMasjid peut apparaître plusieurs fois — on compte les occurrences
    final tahiyyat = _lastPrayers!.where((p) => p.isTahiyyat).length;
    final others = _lastPrayers!.where((p) => !p.isTahiyyat).toSet();
    setState(() {
      _prayersAlone
        ..clear()
        ..addAll(others);
      _tahiyyatCount = tahiyyat;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final cycle = state.cycleSummary;

    final canCommit = _effectivePrayers.isNotEmpty;

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
                      style: GoogleFonts.amiri(fontSize: 15, color: context.palette.gold)),
                ).animate().fadeIn(),
                const SizedBox(height: 10),
                Text(S.reviserAujourdhui,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: context.palette.textPrimary)),
                const SizedBox(height: 10),
                const Center(child: OrnamentalDivider(lineWidth: 26)),
                const SizedBox(height: 18),
                CycleProgressCard(
                  progress: cycle.progress,
                  pos: cycle.pos,
                  total: cycle.total,
                  daysRemaining: cycle.daysRemaining,
                  streak: _streak,
                ),
                const SizedBox(height: 16),
                HadithCard(hadith: hadithDuJour(DateTime.now())),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(S.priereSeul,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold))
                        .animate()
                        .fadeIn(delay: 150.ms),
                    if (_lastPrayers != null)
                      TextButton.icon(
                        onPressed: _applyLastPrayers,
                        icon: const Icon(Icons.history, size: 16),
                        label: Text(
                          _isYesterday ? S.commeHier : S.derniereSelection,
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ).animate().fadeIn(duration: 200.ms),
                  ],
                ),
                const SizedBox(height: 10),
                KeyedSubtree(
                  key: TourKeys.prayerSelector,
                  child: PrayerSelector(
                    selected: _prayersAlone,
                    onToggle: (p) => setState(() {
                      _prayersAlone.contains(p)
                          ? _prayersAlone.remove(p)
                          : _prayersAlone.add(p);
                    }),
                    tahiyyatCount: _tahiyyatCount,
                    onTahiyyatCountChanged: (n) =>
                        setState(() => _tahiyyatCount = n),
                  ),
                ),
                const SizedBox(height: 24),
                KeyedSubtree(
                  key: TourKeys.voirPlanButton,
                  child: PrimaryCtaButton(
                    onPressed: canCommit
                        ? () => widget.onVoirPlan(_effectivePrayers)
                        : null,
                    icon: Icons.calendar_today_outlined,
                    label: S.voirPlanDuJour,
                  ),
                ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1),
                if (widget.onSaisirManuel != null)
                  TextButton(
                    onPressed: widget.onSaisirManuel,
                    child: Text(S.saisirManuellement),
                  ).animate().fadeIn(delay: 300.ms),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
