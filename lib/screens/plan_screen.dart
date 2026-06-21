import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_colors.dart';
import '../core/freshness_engine.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';
import '../models/revision_unit.dart';
import '../widgets/prayer_plan_card.dart';
import '../widgets/preview_banner.dart';

class PlanScreen extends StatefulWidget {
  final DailySession session;
  final Future<void> Function(int unitsCompleted)? onComplete;
  final VoidCallback? onEngager;
  final VoidCallback? onChangePlan;
  final bool isPreview;
  /// Retourne le niveau de fraîcheur d'une sourate. Null si pas encore chargé.
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.modifierPlan),
        content: Text(S.modifierPlanConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(S.annuler),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(S.modifierPlan),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onChangePlan?.call();
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CompletionSummarySheet(session: widget.session),
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.session.isOnTrack
            ? cs.primaryContainer
            : cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            S.unitesRakaas(
                widget.session.totalUnits, widget.session.totalRakaas),
            style: TextStyle(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
          Text(
            widget.session.isOnTrack ? S.dansLesTemps : S.prendsAvance,
            style: TextStyle(
              color: widget.session.isOnTrack
                  ? cs.onPrimaryContainer
                  : cs.onTertiaryContainer,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionSummarySheet extends StatelessWidget {
  final DailySession session;
  const _CompletionSummarySheet({required this.session});

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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(S.felicitationsRevision,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 4),
          Text(S.resumeSessionLabel,
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          ...session.plan.map((pp) => _prayerRow(cs, pp)),
          const SizedBox(height: 24),
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
    ).animate().slideY(begin: 0.15, duration: 300.ms, curve: Curves.easeOut);
  }

  Widget _prayerRow(ColorScheme cs, PrayerPlan pp) {
    final units = _unitsForPrayer(pp);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.greenContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mosque_outlined,
                size: 18, color: AppColors.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pp.prayer.nameFr,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: cs.onSurface)),
                const SizedBox(height: 2),
                Text(
                  units.isEmpty
                      ? S.alFatihaSeul
                      : units.map((u) => u.label).join(' · '),
                  style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
