import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:quran/quran.dart' as quran;
import '../core/app_colors.dart';
import '../core/freshness_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../services/history_service.dart';
import '../state/app_state.dart';
import '../widgets/prayer_plan_card.dart';
import '../widgets/preview_banner.dart';

class PlanScreen extends StatefulWidget {
  final DailySession session;
  final Future<void> Function(int unitsCompleted)? onComplete;
  final VoidCallback? onEngager;
  final VoidCallback? onChangePlan;
  final bool isPreview;
  final FreshnessLevel? Function(int sourateId)? freshnessOf;

  const PlanScreen({
    super.key,
    required this.session,
    this.onComplete,
    this.onEngager,
    this.onChangePlan,
    this.isPreview = false,
    this.freshnessOf,
  });

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final Map<int, Set<int>> _checked = {};
  bool _justCompleted = false;

  bool get _allDone {
    for (int pi = 0; pi < widget.session.plan.length; pi++) {
      final pp = widget.session.plan[pi];
      final checked = _checked[pi] ?? {};
      for (final r in pp.rakaas) {
        if (r.unit != null && !checked.contains(r.rakaaNumber)) return false;
      }
    }
    return true;
  }

  int get _totalRakaasWithUnit {
    int count = 0;
    for (final pp in widget.session.plan) {
      count += pp.rakaas.where((r) => r.unit != null).length;
    }
    return count;
  }

  int get _checkedCount =>
      _checked.values.fold(0, (sum, s) => sum + s.length);

  Future<void> _confirmChangePlan(BuildContext context) async {
    if (widget.isPreview) {
      widget.onChangePlan?.call();
      return;
    }
    // Commitment modal — l'utilisateur doit déclarer ce qu'il a fait.
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommitmentSheet(
        totalRakaas: _totalRakaasWithUnit,
        onToutFait: () async {
          Navigator.pop(context);
          if (mounted) await widget.onComplete!(widget.session.totalUnits);
        },
        onPartFait: (n) async {
          Navigator.pop(context);
          if (mounted) await widget.onComplete!(n);
        },
        onRienFait: () {
          Navigator.pop(context);
          widget.onChangePlan?.call();
        },
      ),
    );
  }

  void _toggle(int prayerIndex, int rakaaNumber) {
    setState(() {
      final set = _checked.putIfAbsent(prayerIndex, () => {});
      set.contains(rakaaNumber) ? set.remove(rakaaNumber) : set.add(rakaaNumber);
      if (_allDone && !_justCompleted) {
        _justCompleted = true;
      } else if (!_allDone) {
        _justCompleted = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = _totalRakaasWithUnit == 0
        ? 1.0
        : _checkedCount / _totalRakaasWithUnit;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(widget.isPreview ? S.planDuJourTitle : S.revisionEnCours),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            pinned: true,
            leading: widget.onChangePlan != null
                ? IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: S.modifierPlan,
                    onPressed: () => _confirmChangePlan(context),
                  )
                : null,
            actions: [
              if (!widget.isPreview)
                IconButton(
                  icon: const Icon(Icons.mosque_outlined),
                  tooltip: S.focusMosquee,
                  onPressed: () => Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => _FocusMosqueeScreen(session: widget.session),
                    ),
                  ),
                ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: ClipRRect(
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                  minHeight: 4,
                ),
              ),
            ),
          ),
          if (widget.isPreview)
            const SliverToBoxAdapter(child: PreviewBanner()),
          SliverToBoxAdapter(child: _summaryBar(cs)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final pp = widget.session.plan[i];
                  return PrayerPlanCard(
                    prayerIndex: i,
                    pp: pp,
                    checked: _checked[i] ?? {},
                    isPreview: widget.isPreview,
                    onToggle: (rakaa) => _toggle(i, rakaa),
                    freshnessOf: widget.freshnessOf,
                  )
                      .animate()
                      .fadeIn(delay: Duration(milliseconds: i * 80))
                      .slideY(begin: 0.06);
                },
                childCount: widget.session.plan.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 56,
            child: widget.isPreview ? _engageButton() : _completionButton(),
          ),
        ),
      ),
    );
  }

  Widget _engageButton() => FilledButton.icon(
        onPressed: widget.onEngager,
        icon: const Icon(Icons.check_rounded),
        label: Text(S.sEngager,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      );

  Future<void> _showCompletionSummary() async {
    final pauseDates = context.read<AppState>().pauseDates;
    // +1 anticipe la session d'aujourd'hui, pas encore enregistrée à ce stade.
    final streakFuture = HistoryService.currentStreak(pauseDates: pauseDates)
        .then((s) => s + 1);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompletionCelebrationSheet(
        session: widget.session,
        streakFuture: streakFuture,
      ),
    );
    if (mounted) await widget.onComplete!(widget.session.totalUnits);
  }

  Widget _completionButton() {
    final button = FilledButton.icon(
      onPressed: _allDone ? _showCompletionSummary : null,
      icon: Icon(_allDone ? Icons.check_circle : Icons.check_circle_outline),
      label: Text(
        _allDone
            ? S.revisionComplete
            : '$_checkedCount / $_totalRakaasWithUnit ${S.rakaasLabel}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );

    if (!_allDone) return button;

    return button
        .animate(key: const ValueKey('done'))
        .scale(
            begin: const Offset(0.92, 0.92),
            end: const Offset(1, 1),
            duration: 350.ms,
            curve: Curves.elasticOut)
        .shimmer(
            duration: 900.ms,
            color: Colors.white.withValues(alpha: 0.4),
            delay: 100.ms);
  }

  Widget _summaryBar(ColorScheme cs) {
    final session = widget.session;
    final isOnTrack = session.isOnTrack;
    final bgColor = isOnTrack ? cs.primaryContainer : cs.tertiaryContainer;
    final cycleEnd =
        (session.cyclePosition + session.totalUnits).clamp(0, session.cycleTotal);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.unitesRakaas(session.totalUnits, session.totalRakaas),
                style: TextStyle(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
              Text(
                isOnTrack ? S.dansLesTemps : S.prendsAvance,
                style: TextStyle(
                  color: isOnTrack
                      ? cs.onPrimaryContainer
                      : cs.onTertiaryContainer,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${S.cycleEnCours} : $cycleEnd / ${session.cycleTotal}',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7), fontSize: 11),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: session.cycleTotal == 0
                        ? 0
                        : cycleEnd / session.cycleTotal,
                    minHeight: 4,
                    backgroundColor: cs.onSurface.withValues(alpha: 0.12),
                    color: cs.onSurface.withValues(alpha: 0.45),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Écran waouh (gamification) ───────────────────────────────────────────────

class _CompletionCelebrationSheet extends StatelessWidget {
  final DailySession session;
  final Future<int> streakFuture;

  const _CompletionCelebrationSheet({
    required this.session,
    required this.streakFuture,
  });

  List<RevisionUnit> _unitsForPrayer(PrayerPlan pp) {
    final seen = <String>{};
    final result = <RevisionUnit>[];
    for (final r in pp.rakaas) {
      if (r.unit != null && seen.add(r.unit!.label)) {
        result.add(r.unit!);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Animation célébration
          const Text('✨', style: TextStyle(fontSize: 52))
              .animate()
              .scale(
                  begin: const Offset(0.3, 0.3),
                  duration: 600.ms,
                  curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 800.ms),
          const SizedBox(height: 12),
          Text(S.waouhIslamic,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.green)),
          const SizedBox(height: 4),
          Text(S.waouhSubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          // Streak
          FutureBuilder<int>(
            future: streakFuture,
            builder: (_, snap) {
              if (!snap.hasData) return const SizedBox(height: 40);
              final streak = snap.data!;
              return _StreakBadge(streak: streak)
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideY(begin: 0.2);
            },
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 8),
          // Résumé session
          ...session.plan.map((pp) => _prayerRow(cs, pp)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(S.terminer,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.15, duration: 350.ms, curve: Curves.easeOut);
  }

  Widget _prayerRow(ColorScheme cs, PrayerPlan pp) {
    final units = _unitsForPrayer(pp);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.greenContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mosque_outlined,
                size: 16, color: AppColors.green),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pp.prayer.nameFr,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: cs.onSurface)),
                Text(
                  units.isEmpty
                      ? S.alFatihaSeul
                      : units.map((u) => u.label).join(' · '),
                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    String message;
    if (streak == 1) {
      message = S.premierJour;
    } else if (streak == 7 || streak == 30 || streak == 100) {
      message = S.nouveauPalier;
    } else {
      message = S.streakJours(streak);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.greenContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
              Text(S.streakLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.green)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Commitment modal ─────────────────────────────────────────────────────────

class _CommitmentSheet extends StatefulWidget {
  final int totalRakaas;
  final Future<void> Function() onToutFait;
  final Future<void> Function(int n) onPartFait;
  final VoidCallback onRienFait;

  const _CommitmentSheet({
    required this.totalRakaas,
    required this.onToutFait,
    required this.onPartFait,
    required this.onRienFait,
  });

  @override
  State<_CommitmentSheet> createState() => _CommitmentSheetState();
}

class _CommitmentSheetState extends State<_CommitmentSheet> {
  int _partialN = 1;
  bool _showPartial = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(S.engagementTitre,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 20),
          if (!_showPartial) ...[
            FilledButton.icon(
              onPressed: widget.onToutFait,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(S.toutFait,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _showPartial = true;
                _partialN = (widget.totalRakaas / 2).round().clamp(1, widget.totalRakaas);
              }),
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(S.unePart,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: widget.onRienFait,
              icon: Icon(Icons.cancel_outlined, color: cs.error),
              label: Text(S.rienFait,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cs.error)),
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ] else ...[
            Text(S.combienRakaas,
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _partialN > 1
                      ? () => setState(() => _partialN--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text('$_partialN',
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: cs.onSurface)),
                ),
                IconButton.filled(
                  onPressed: _partialN < widget.totalRakaas
                      ? () => setState(() => _partialN++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => widget.onPartFait(_partialN),
              child: Text(S.valider,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _showPartial = false),
              child: Text(S.annuler),
            ),
          ],
        ],
      ),
    ).animate().slideY(begin: 0.2, duration: 300.ms, curve: Curves.easeOut);
  }
}

// ─── Mode focus mosquée ───────────────────────────────────────────────────────

class _FocusMosqueeScreen extends StatelessWidget {
  final DailySession session;
  const _FocusMosqueeScreen({required this.session});

  List<RevisionUnit> get _uniqueUnits {
    final seen = <String>{};
    final result = <RevisionUnit>[];
    for (final pp in session.plan) {
      for (final r in pp.rakaas) {
        if (r.unit != null && seen.add(r.unit!.label)) {
          result.add(r.unit!);
        }
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final units = _uniqueUnits;
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Stack(
          children: [
            ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              itemCount: units.length,
              separatorBuilder: (_, _) => Divider(
                  color: Colors.white.withValues(alpha: 0.12),
                  height: 32),
              itemBuilder: (_, i) {
                final unit = units[i];
                final verses = List.generate(
                  unit.verseCount,
                  (j) => quran.getVerse(
                      unit.sourate.id, unit.verseStart + j,
                      verseEndSymbol: true),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      unit.sourate.nameAr,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 13,
                          letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      verses.join('  '),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 2.2,
                      ),
                    ),
                  ],
                );
              },
            ),
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  label: Text(S.quitterFocus),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
