import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../models/sourate.dart';
import '../state/app_state.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/verse_chip.dart';

/// Popup affiché une fois par jour généré (voir `AppState.justCheckedIn`) :
/// montre/édite les unités déjà écrites par le moteur quotidien dans
/// `ayah_facts` (`reach=0, checked_out=0`) — ajouter/retirer une sourate ou
/// étendre une plage écrit/efface directement ces lignes, il n'y a pas
/// d'objet "plan" séparé à promouvoir (voir cadrage Phase 6).
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  List<RevisionUnit>? _units;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final units = await context.read<AppState>().dayUnits();
    if (!mounted) return;
    setState(() => _units = units);
  }

  Future<void> _remove(RevisionUnit unit) async {
    await context.read<AppState>().removeFromDayPlan(unit.sourate.id);
    await _load();
  }

  Future<void> _addSourate(Sourate s) async {
    await context.read<AppState>().addToDayPlan(
        RevisionUnit(sourate: s, verseStart: 1, verseEnd: s.verses, isWhole: true));
    await _load();
  }

  Future<void> _openAddSheet() async {
    final state = context.read<AppState>();
    final present = _units!.map((u) => u.sourate.id).toSet();
    final candidates = state.sourates.where((s) => !present.contains(s.id)).toList();
    final picked = await showModalBottomSheet<Sourate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSourateSheet(candidates: candidates),
    );
    if (picked != null) await _addSourate(picked);
  }

  Future<void> _openDetail(RevisionUnit unit) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _CheckInDetailScreen(unit: unit),
    ));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final palette = context.palette;
    final units = _units;

    return Scaffold(
      backgroundColor: palette.cream,
      body: units == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _hero(palette, units.fold(0, (s, u) => s + u.verseCount)),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      children: [
                        ..._watchSection(palette, state, units),
                        _sectionLabel(palette, S.checkInVueDuJour),
                        const SizedBox(height: 8),
                        for (final unit in units)
                          _UnitRow(
                            unit: unit,
                            lastLabel: S.lastRevisionLabel(
                                state.lastRevisionFor(unit.sourate.id), DateTime.now()),
                            onTap: () => _openDetail(unit),
                            onRemove: () => _remove(unit),
                          ),
                        const SizedBox(height: 14),
                        _addButton(palette),
                      ],
                    ),
                  ),
                  _ctaBar(palette),
                ],
              ),
            ),
    );
  }

  Widget _hero(AppPalette palette, int totalVerses) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
        decoration: BoxDecoration(
          color: palette.primary,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Text(S.checkInEyebrow,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: palette.onPrimary.withValues(alpha: 0.65))),
            const SizedBox(height: 10),
            Text(S.checkInTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w600, color: palette.onPrimary)),
            const SizedBox(height: 8),
            Text(S.checkInVersesProposed(totalVerses),
                style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: palette.onPrimary.withValues(alpha: 0.82))),
          ],
        ),
      );

  List<Widget> _watchSection(AppPalette palette, AppState state, List<RevisionUnit> units) {
    final watch = units
        .where((u) => S.needsAttention(state.lastRevisionFor(u.sourate.id), DateTime.now()))
        .toList();
    if (watch.isEmpty) return const [];
    return [
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel(palette, S.checkInAPrioriser, padded: false),
            const SizedBox(height: 8),
            for (final u in watch)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(u.sourate.nameFr,
                        style: TextStyle(fontSize: 12.5, color: palette.textPrimary)),
                    Text(
                        S.lastRevisionLabel(
                            state.lastRevisionFor(u.sourate.id), DateTime.now()),
                        style: TextStyle(fontSize: 11, color: palette.danger)),
                  ],
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _sectionLabel(AppPalette palette, String text, {bool padded = true}) => Padding(
        padding: padded ? const EdgeInsets.only(bottom: 0) : EdgeInsets.zero,
        child: Text(text.toUpperCase(),
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: palette.textMuted)),
      );

  Widget _addButton(AppPalette palette) => InkWell(
        onTap: _openAddSheet,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.gold.withValues(alpha: 0.7), style: BorderStyle.solid),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 16, color: palette.textPrimary),
              const SizedBox(width: 8),
              Text(S.checkInAjouterSourate,
                  style: TextStyle(fontSize: 13, color: palette.textPrimary)),
            ],
          ),
        ),
      );

  Widget _ctaBar(AppPalette palette) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SizedBox(
          height: 52,
          child: PrimaryCtaButton(
            label: S.checkInValider,
            icon: Icons.check_rounded,
            // Les ajouts/retraits/extensions sont déjà écrits en direct dans
            // ayah_facts (voir _addSourate/_remove/_extend) — "Valider" ne
            // fait que fermer le popup, pas de promotion d'un objet séparé.
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      );
}

class _UnitRow extends StatelessWidget {
  final RevisionUnit unit;
  final String lastLabel;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _UnitRow({
    required this.unit,
    required this.lastLabel,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: palette.surfaceCardSolid,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.cardBorder),
          ),
          child: Row(
            children: [
              _arabicInitial(palette, unit.sourate),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary),
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
                    const SizedBox(height: 1),
                    Text(lastLabel, style: TextStyle(fontSize: 11, color: palette.textMuted)),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRemove,
                icon: Icon(Icons.close, size: 16, color: palette.textMuted),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _arabicInitial(AppPalette palette, Sourate s) => Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: palette.gold.withValues(alpha: 0.55), width: 2),
      ),
      child: Text(s.nameAr.characters.first,
          style: GoogleFonts.amiri(fontSize: 16, color: palette.goldDark)),
    );

class _AddSourateSheet extends StatelessWidget {
  final List<Sourate> candidates;
  const _AddSourateSheet({required this.candidates});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: palette.surfaceCardSolid,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: palette.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(S.checkInAjouterSourate,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: palette.textPrimary)),
          const SizedBox(height: 2),
          Text(S.checkInAjouterDesc,
              style: TextStyle(fontSize: 11, color: palette.textMuted)),
          const SizedBox(height: 14),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: candidates.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = candidates[i];
                return InkWell(
                  onTap: () => Navigator.pop(context, s),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.surfaceCard,
                      border: Border.all(color: palette.cardBorder),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _arabicInitial(palette, s),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(s.nameFr,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: palette.textPrimary)),
                        ),
                        Icon(Icons.add, size: 14, color: palette.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckInDetailScreen extends StatefulWidget {
  final RevisionUnit unit;
  const _CheckInDetailScreen({required this.unit});

  @override
  State<_CheckInDetailScreen> createState() => _CheckInDetailScreenState();
}

class _CheckInDetailScreenState extends State<_CheckInDetailScreen> {
  late RevisionUnit _unit;
  bool _extending = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
  }

  Future<void> _extend() async {
    if (_extending) return; // évite un double-tap qui étendrait de 2 versets
    final next = _unit.verseEnd + 1;
    if (next > _unit.sourate.verses) return;
    setState(() => _extending = true);
    await context.read<AppState>().extendDayPlanVerse(_unit.sourate.id, next);
    if (!mounted) return;
    setState(() {
      _extending = false;
      _unit = RevisionUnit(
          sourate: _unit.sourate,
          verseStart: _unit.verseStart,
          verseEnd: next,
          isWhole: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      backgroundColor: palette.cream,
      appBar: AppBar(
        backgroundColor: palette.cream,
        title: Text('${_unit.sourate.nameFr} · v.${_unit.verseStart}–${_unit.verseEnd}',
            style: TextStyle(fontSize: 15, color: palette.textPrimary)),
        iconTheme: IconThemeData(color: palette.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.checkInVersetsInclus.toUpperCase(),
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
                for (int v = _unit.verseStart; v <= _unit.verseEnd; v++)
                  VerseChip(
                    borderColor: palette.cardBorder,
                    child: Text('$v', style: TextStyle(fontSize: 11, color: palette.textMuted)),
                  ),
                if (_unit.verseEnd < _unit.sourate.verses)
                  VerseChip(
                    borderColor: palette.gold.withValues(alpha: 0.7),
                    onTap: _extend,
                    child: Icon(Icons.add, size: 14, color: palette.textPrimary),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(S.checkInExtendHint,
                style: TextStyle(
                    fontSize: 11, fontStyle: FontStyle.italic, color: palette.textMuted)),
          ],
        ),
      ),
    );
  }
}
