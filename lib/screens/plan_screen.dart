import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../widgets/prayer_plan_card.dart';
import '../widgets/preview_banner.dart';

class PlanScreen extends StatefulWidget {
  final DailySession session;
  final void Function(int unitsCompleted)? onComplete;
  final VoidCallback? onEngager;
  final VoidCallback? onChangePlan;
  final bool isPreview;

  const PlanScreen({
    super.key,
    required this.session,
    this.onComplete,
    this.onEngager,
    this.onChangePlan,
    this.isPreview = false,
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
                    tooltip: 'Modifier le plan',
                    onPressed: widget.onChangePlan,
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

  Widget _completionButton() {
    final button = FilledButton.icon(
      onPressed:
          _allDone ? () => widget.onComplete!(widget.session.totalUnits) : null,
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
            ? const Color(0xFFE8F5E9)
            : Colors.orange.shade50,
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
                  ? const Color(0xFF2E7D32)
                  : Colors.orange.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
