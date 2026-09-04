import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../state/app_state.dart';
import '../widgets/cycle_milestone_dialog.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/verse_chip.dart';

/// Popup de rattrapage : scelle un jour de révision non encore clôturé
/// (`checked_out = 0`) — c'est le seul moment où `cyclePosition` avance
/// (voir `AppState.checkOut`). Tant qu'un jour est en attente, aucun nouveau
/// check-in n'est proposé (voir cadrage Phase 6, gating du moteur quotidien).
class CheckOutScreen extends StatefulWidget {
  final String date; // YYYY-MM-DD, jour en attente à clôturer
  const CheckOutScreen({super.key, required this.date});

  @override
  State<CheckOutScreen> createState() => _CheckOutScreenState();
}

class _CheckOutScreenState extends State<CheckOutScreen> {
  List<({RevisionUnit unit, Set<int> coldVerses})>? _items;
  // Unités décochées par l'utilisateur (exceptions) — tout le reste est
  // "fait" par défaut, écrit en base seulement à la clôture ([_close]).
  final Set<RevisionUnit> _unchecked = {};
  int _step = 1;
  bool _addToday = false;
  bool _sealing = false;

  bool get _isMultiDay =>
      DateTime.now().difference(DateTime.parse(widget.date)).inDays > 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items =
        await context.read<AppState>().dayUnitsWithStatus(date: widget.date);
    if (!mounted) return;
    setState(() => _items = items);
  }

  void _toggleReach(RevisionUnit unit) {
    setState(() {
      if (!_unchecked.add(unit)) _unchecked.remove(unit);
    });
  }

  Future<void> _openDetail(
      RevisionUnit unit, Set<int> coldVerses) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          _CheckOutDetailScreen(date: widget.date, unit: unit, initialCold: coldVerses),
    ));
    await _load();
  }

  Future<void> _close() async {
    if (_sealing) return;
    setState(() => _sealing = true);
    try {
      final state = context.read<AppState>();
      // Le check-out est "fait par défaut" : les unités restées cochées
      // sont confirmées reach=1. Les exceptions décochées repassent
      // explicitement à reach=0 — nécessaire même si `proposeUnits` les a
      // déjà écrites à 0, car une unité peut avoir reach=1 depuis plus tôt
      // dans la journée (rakaa cochée dans PlanScreen avant que le jour ne
      // devienne "en attente") : annuler une progression doit repasser
      // reach à 0, jamais rester un no-op silencieux (voir CLAUDE.md § «
      // Modèle de données central »).
      final stillChecked = <RevisionUnit>[];
      final uncheckedNow = <RevisionUnit>[];
      for (final it in _items!) {
        (_unchecked.contains(it.unit) ? uncheckedNow : stillChecked).add(it.unit);
      }
      await Future.wait([
        state.markUnitsReached(stillChecked, date: widget.date),
        state.markUnitsReached(uncheckedNow, date: widget.date, reach: false),
      ]);
      final cycleWrapped = await state.checkOut(widget.date);
      // Le jour en attente est scellé. Écart d'1 jour : pas de choix
      // proposé, on enchaîne directement sur aujourd'hui comme avant.
      // Écart multi-jours (Partie 2) : ne propose aujourd'hui que si
      // l'utilisateur l'a explicitement demandé via le toggle — sinon
      // "Terminer sans aujourd'hui" doit vraiment différer, pas générer le
      // plan quand même à la ligne suivante (bug trouvé en revue de code).
      if (!_isMultiDay || _addToday) await state.ensureDayPlan();
      if (!mounted) return;
      if (cycleWrapped) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const CycleMilestoneDialog(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _sealing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = _items;
    final showPart2 = _isMultiDay && _step == 2;

    return PopScope(
      canPop: !_sealing,
      child: Scaffold(
        backgroundColor: palette.cream,
        body: items == null
            ? const Center(child: CircularProgressIndicator())
            : SafeArea(
                child: Column(
                  children: [
                    _hero(palette, showPart2),
                    Expanded(
                      child: showPart2
                          ? _part2Body(palette)
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              children: [
                                for (final it in items)
                                  _CheckOutRow(
                                    unit: it.unit,
                                    reach: !_unchecked.contains(it.unit),
                                    onToggle: () => _toggleReach(it.unit),
                                    onDetail: () => _openDetail(it.unit, it.coldVerses),
                                  ),
                              ],
                            ),
                    ),
                    _ctaBar(palette, showPart2),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _hero(AppPalette palette, bool showPart2) {
    final gapDays = DateTime.now().difference(DateTime.parse(widget.date)).inDays;
    final title = showPart2
        ? S.checkOutTitreAujourdhui
        : (_isMultiDay ? S.checkOutTitreEnAttente : S.checkOutTitreHier);
    final badge = showPart2
        ? S.checkOutPartieOptionnelle
        : (_isMultiDay ? S.checkOutIlYaNJours(gapDays) : S.checkOutHier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: palette.primary,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Text(_isMultiDay ? S.checkOutRattrapageEyebrow : S.checkOutEyebrow,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: palette.onPrimary.withValues(alpha: 0.65))),
          if (_isMultiDay) ...[
            const SizedBox(height: 10),
            _stepDots(palette, showPart2),
          ],
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 21, fontWeight: FontWeight.w600, color: palette.onPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: palette.onPrimary.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(badge,
                style: TextStyle(fontSize: 10, color: palette.onPrimary.withValues(alpha: 0.82))),
          ),
        ],
      ),
    );
  }

  Widget _stepDots(AppPalette palette, bool showPart2) {
    Widget dot(bool active, String label) => Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? palette.gold : Colors.transparent,
            border: Border.all(color: palette.gold),
          ),
          child: Text(label,
              style: TextStyle(fontSize: 11, color: palette.onPrimary)),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dot(!showPart2, '1'),
        Container(width: 24, height: 1, color: palette.gold),
        dot(showPart2, '2'),
      ],
    );
  }

  Widget _part2Body(AppPalette palette) {
    final preview = context.read<AppState>().previewTodayUnits();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.checkOutAjouterAujourdhui,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary)),
                    const SizedBox(height: 2),
                    Text(S.checkOutAjouterDesc,
                        style: TextStyle(fontSize: 11, color: palette.textMuted)),
                  ],
                ),
              ),
              Switch(
                value: _addToday,
                onChanged: (v) => setState(() => _addToday = v),
                activeThumbColor: palette.primary,
              ),
            ],
          ),
        ),
        if (_addToday) ...[
          const SizedBox(height: 10),
          for (final unit in preview)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: palette.surfaceCardSolid,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                children: [
                  Text(unit.sourate.nameAr,
                      style: GoogleFonts.amiri(fontSize: 15, color: palette.goldDark)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit.sourate.nameFr,
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: palette.textPrimary)),
                        Text('v.${unit.verseStart}–${unit.verseEnd}',
                            style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: palette.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _ctaBar(AppPalette palette, bool showPart2) {
    String label;
    VoidCallback? onPressed;
    if (!_isMultiDay) {
      label = S.checkOutCloturerHier;
      onPressed = _sealing ? null : _close;
    } else if (!showPart2) {
      label = S.checkOutCloturerJour;
      onPressed = () => setState(() => _step = 2);
    } else {
      label = _addToday ? S.checkOutValiderAujourdhui : S.checkOutTerminerSans;
      onPressed = _sealing ? null : _close;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SizedBox(
        height: 52,
        child: PrimaryCtaButton(label: label, onPressed: onPressed),
      ),
    );
  }
}

class _CheckOutRow extends StatelessWidget {
  final RevisionUnit unit;
  final bool reach;
  final VoidCallback onToggle;
  final VoidCallback onDetail;

  const _CheckOutRow({
    required this.unit,
    required this.reach,
    required this.onToggle,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: palette.surfaceCardSolid,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: reach ? palette.primary : Colors.transparent,
                        border: Border.all(
                            color: reach ? palette.primary : palette.cardBorder),
                      ),
                      child: reach
                          ? Icon(Icons.check, size: 15, color: palette.onPrimary)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: reach ? palette.textPrimary : palette.textMuted),
                          children: [
                            TextSpan(text: unit.sourate.nameFr),
                            TextSpan(
                              text: '  ·  v.${unit.verseStart}–${unit.verseEnd}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 11.5,
                                  color: palette.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            InkWell(
              onTap: onDetail,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Row(
                  children: [
                    Text(S.checkOutVoirVersets(unit.verseCount),
                        style: TextStyle(fontSize: 11.5, color: palette.goldDark)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckOutDetailScreen extends StatefulWidget {
  final String date;
  final RevisionUnit unit;
  final Set<int> initialCold;

  const _CheckOutDetailScreen({
    required this.date,
    required this.unit,
    required this.initialCold,
  });

  @override
  State<_CheckOutDetailScreen> createState() => _CheckOutDetailScreenState();
}

class _CheckOutDetailScreenState extends State<_CheckOutDetailScreen> {
  late Set<int> _cold;

  @override
  void initState() {
    super.initState();
    _cold = {...widget.initialCold};
  }

  Future<void> _toggle(int verse) async {
    final flagged = !_cold.contains(verse);
    await context
        .read<AppState>()
        .setVerseCold(widget.date, widget.unit.sourate.id, verse, flagged);
    if (!mounted) return;
    setState(() {
      flagged ? _cold.add(verse) : _cold.remove(verse);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unit = widget.unit;
    return Scaffold(
      backgroundColor: palette.cream,
      appBar: AppBar(
        backgroundColor: palette.cream,
        title: Text('${unit.sourate.nameFr} · v.${unit.verseStart}–${unit.verseEnd}',
            style: TextStyle(fontSize: 15, color: palette.textPrimary)),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.checkOutARetravailler.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: palette.textMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int v = unit.verseStart; v <= unit.verseEnd; v++)
                  VerseChip(
                    onTap: () => _toggle(v),
                    borderColor: _cold.contains(v) ? palette.gold : palette.cardBorder,
                    fillColor: _cold.contains(v) ? palette.gold : null,
                    child: _cold.contains(v)
                        ? Icon(Icons.bookmark, size: 14, color: palette.onPrimary)
                        : Text('$v', style: TextStyle(fontSize: 11, color: palette.textMuted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
