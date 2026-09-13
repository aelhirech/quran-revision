part of 'check_out_screen.dart';

/// Sections secondaires du check-out : « réviser en plus », le volet
/// apprentissage, et la partie 2 optionnelle du rattrapage multi-jours (voir
/// doc de [CheckOutScreen]).
extension _CheckOutSections on _CheckOutScreenState {
  /// « J'ai révisé une sourate en plus » — le pendant du décochage : le
  /// check-out confirme ce qui a réellement été fait, en moins **comme en
  /// plus**. La sourate rejoint le plan de ce jour-là et son "fait par
  /// défaut" la confirmera à la clôture ; comme tout ajout hors-sélection,
  /// elle alimente historique et fraîcheur sans faire avancer le cycle
  /// au-delà de ce que le moteur avait proposé (voir `AppState.checkOut`).
  /// Choix de la sourate puis de la **portion** réellement révisée
  /// (`VerseRangePicker`, le même sélecteur que l'onboarding) — on peut
  /// n'avoir fait qu'une partie de la sourate en plus. Fermer le sélecteur
  /// de plage sans confirmer annule l'ajout : la sourate n'a été
  /// présélectionnée que pour pouvoir l'ouvrir.
  Future<void> _addRevisedSourate() async {
    final state = context.read<AppState>();
    final present = _items!.map((it) => it.unit.sourate.id).toSet();
    final candidates =
        state.sourates.where((s) => !present.contains(s.id)).toList();
    final picked = await showModalBottomSheet<Sourate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SouratePickerSheet(
          sourates: candidates, title: S.checkOutSourateEnPlusTitre),
    );
    if (picked == null || !mounted) return;
    final range = await showModalBottomSheet<SourateSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseRangePicker(
          sourate: picked, current: SourateSelection.whole(picked)),
    );
    if (range == null || !mounted) return;
    await state.addToDayPlan(
      RevisionUnit(
        sourate: picked,
        verseStart: range.verseStart,
        verseEnd: range.verseEnd,
        isWhole: range.isWhole,
      ),
      date: widget.date,
    );
    await _load();
  }

  Future<void> _addLearnedVerse() async {
    await context.read<AppState>().extendLearningForDate(widget.date);
    await _load();
  }

  /// Volet apprentissage (Phase 9) : les versets proposés à la mémorisation
  /// ce jour-là, cochés par défaut. Décocher un verset le laisse `reach = 0`
  /// — il repassera dans la proposition du lendemain. Le chip « + » déclare
  /// un verset appris **en plus** de ce qui était prévu.
  List<Widget> _learnSection(AppPalette palette) {
    final learn = _learnPlan;
    if (learn == null || learn.ayahIds.isEmpty) return const [];
    return [
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.checkOutApprentissage.toUpperCase(),
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                    color: palette.textMuted)),
            const SizedBox(height: 6),
            Text('${learn.sourate.nameFr} · ${learn.sourate.nameAr}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: palette.textPrimary)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in learn.ayahIds)
                  VerseChip(
                    borderColor: _notLearned.contains(v)
                        ? palette.cardBorder
                        : palette.gold.withValues(alpha: 0.8),
                    onTap: () => _setState(() {
                      if (!_notLearned.add(v)) _notLearned.remove(v);
                    }),
                    child: Text('$v',
                        style: TextStyle(
                            fontSize: 11,
                            color: _notLearned.contains(v)
                                ? palette.textMuted
                                : palette.goldDark)),
                  ),
                if (learn.ayahIds.length < learn.sourate.verses)
                  VerseChip(
                    borderColor: palette.gold.withValues(alpha: 0.7),
                    onTap: _addLearnedVerse,
                    child: Icon(Icons.add, size: 14, color: palette.textPrimary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(S.checkOutApprentissageDesc,
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: palette.textMuted)),
            Text(S.checkOutApprisEnPlusHint,
                style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: palette.textMuted)),
          ],
        ),
      ),
    ];
  }

  Widget _part2Body(AppPalette palette) {
    final preview = context.read<AppState>().todayPreviewUnits;
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
                    Text(
                      S.checkOutAjouterAujourdhui,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      S.checkOutAjouterDesc,
                      style: TextStyle(
                        fontSize: 11,
                        color: palette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _addToday,
                onChanged: (v) => _setState(() => _addToday = v),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: palette.surfaceCardSolid,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.cardBorder),
              ),
              child: Row(
                children: [
                  Text(
                    unit.sourate.nameAr,
                    style: GoogleFonts.amiri(
                      fontSize: 15,
                      color: palette.goldDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          unit.sourate.nameFr,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: palette.textPrimary,
                          ),
                        ),
                        Text(
                          'v.${unit.verseStart}–${unit.verseEnd}',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: palette.textMuted,
                          ),
                        ),
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
}
