import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/hadith_data.dart';
import '../core/strings.dart';
import '../models/daily_session.dart';
import '../core/prayer_l10n.dart';
import '../models/prayer.dart';

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

  int get _checkedCount {
    return _checked.values.fold(0, (sum, s) => sum + s.length);
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
              child: _progressBar(cs, progress),
            ),
          ),
          if (widget.isPreview)
            SliverToBoxAdapter(child: _previewBanner(cs)),
          SliverToBoxAdapter(child: _summaryBar(cs)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _prayerCard(context, i, widget.session.plan[i], cs)
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: i * 80))
                    .slideY(begin: 0.06),
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
            child: widget.isPreview
                ? FilledButton.icon(
                    onPressed: widget.onEngager,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(S.sEngager,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  )
                : _completionButton(),
          ),
        ),
      ),
    );
  }

  Widget _completionButton() {
    final button = FilledButton.icon(
      onPressed: _allDone
          ? () => widget.onComplete!(widget.session.totalUnits)
          : null,
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
        .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1), duration: 350.ms, curve: Curves.elasticOut)
        .shimmer(duration: 900.ms, color: Colors.white.withValues(alpha: 0.4), delay: 100.ms);
  }

  Widget _previewBanner(ColorScheme cs) {
    final h = intentionHadith;
    final text = S.locale == 'en' ? h.textEn : h.textFr;
    final source = S.locale == 'en' ? h.sourceEn : h.sourceFr;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_outlined, color: cs.primary, size: 16),
              const SizedBox(width: 8),
              Text(S.apercuBanniere,
                  style: TextStyle(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12)),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(Icons.format_quote_rounded, color: cs.primary, size: 16),
              const SizedBox(width: 6),
              Text(S.intentionLabel,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: cs.primary,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: cs.onPrimaryContainer,
                  height: 1.5)),
          const SizedBox(height: 6),
          Text(source,
              style: TextStyle(
                  fontSize: 11,
                  color: cs.onPrimaryContainer.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _progressBar(ColorScheme cs, double progress) {
    return ClipRRect(
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: cs.surfaceContainerHighest,
        color: cs.primary,
        minHeight: 4,
      ),
    );
  }

  Widget _summaryBar(ColorScheme cs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.session.isOnTrack
            ? AppColors.greenContainer
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            S.unitesRakaas(widget.session.totalUnits, widget.session.totalRakaas),
            style: TextStyle(
                color: cs.onSurface, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            widget.session.isOnTrack ? S.dansLesTemps : S.prendsAvance,
            style: TextStyle(
              color: widget.session.isOnTrack
                  ? AppColors.green
                  : Colors.orange.shade800,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _prayerCard(
      BuildContext context, int prayerIndex, PrayerPlan pp, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête prière
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.greenContainer,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pp.prayer.displayName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.green,
                        fontSize: 15)),
                Text(pp.prayer.nameAr,
                    style: const TextStyle(
                        color: AppColors.green, fontSize: 17)),
              ],
            ),
          ),
          // Rakaas
          ...pp.rakaas.map((r) => _rakaaRow(prayerIndex, r, cs)),
        ],
      ),
    );
  }

  Widget _rakaaRow(int prayerIndex, RakaaAssignment r, ColorScheme cs) {
    final hasUnit = r.unit != null;
    final isChecked =
        (_checked[prayerIndex] ?? {}).contains(r.rakaaNumber);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: hasUnit && !widget.isPreview
          ? () {
              HapticFeedback.selectionClick();
              setState(() {
                final set = _checked.putIfAbsent(prayerIndex, () => {});
                isChecked ? set.remove(r.rakaaNumber) : set.add(r.rakaaNumber);
                if (_allDone && !_justCompleted) {
                  _justCompleted = true;
                  HapticFeedback.heavyImpact();
                } else if (!_allDone) {
                  _justCompleted = false;
                }
              });
            }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isChecked
                  ? AppColors.green
                  : hasUnit
                      ? AppColors.greenContainer
                      : cs.surfaceContainerHighest,
              border: Border.all(
                color: isChecked
                    ? AppColors.green
                    : hasUnit
                        ? AppColors.green.withValues(alpha: 0.3)
                        : Colors.transparent,
              ),
            ),
            child: Center(
              child: isChecked
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : Text('${r.rakaaNumber}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasUnit
                              ? AppColors.green
                              : cs.onSurfaceVariant)),
            ),
          ),
          title: hasUnit
              ? Text(
                  r.unit!.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    decoration:
                        isChecked ? TextDecoration.lineThrough : null,
                    color: isChecked ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                )
              : Text(S.alFatihaSeul,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 13)),
          subtitle: hasUnit && !r.unit!.isWhole
              ? Text('${r.unit!.verseCount} ${S.versets}',
                  style:
                      TextStyle(color: cs.onSurfaceVariant, fontSize: 11))
              : null,
          dense: true,
        ),
      ),
    );
  }
}


