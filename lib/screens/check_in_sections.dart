part of 'check_in_screen.dart';

/// Les 3 sections du check-in (rythme+révision, apprentissage, prières) —
/// affichées une à la fois selon `_step`, mais ce sont des sections d'un même
/// écran, pas des pages de wizard séparées (voir doc de [CheckInScreen]).
extension _CheckInSections on _CheckInScreenState {
  // Freshness classification computed only in case 0, the only step reading it.
  List<Widget> _stepChildren(
      AppPalette palette, AppState state, List<RevisionUnit> units) {
    switch (_step) {
      case 0:
        final freshnessByUnit = {
          for (final u in units)
            u: state.freshnessFor(u.sourate.id, u.verseStart, u.verseEnd),
        };
        return [
          _rhythmSection(palette, state),
          const SizedBox(height: 22),
          _sectionLabel(palette, SCheckIn.checkInVueDuJour),
          const SizedBox(height: 8),
          for (final unit in units)
            UnitRow(
              unit: unit,
              subtitle: freshnessDiscreetLabel(freshnessByUnit[unit]!),
              onTap: () => _openDetail(unit),
              trailingIcon: Icons.close,
              onTrailing: () => _remove(unit),
            ),
          const SizedBox(height: 14),
          OutlinedActionButton(
              icon: Icons.add,
              label: SCheckIn.checkInAjouterSourate,
              onTap: _openAddSheet),
        ];
      case 1:
        return [_learningSection(palette, state)];
      case 2:
      default: // _step is a plain int, never statically exhaustive
        return [_prayerSection(palette)];
    }
  }

  Widget _rhythmSection(AppPalette palette, AppState state) {
    final current = state.config?.pagesPerDay ?? 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(palette, SCheckIn.checkInRythme),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in pagesPerDayPresets)
              PillChip(
                label: S.pagesParJour(p),
                selected: p == current,
                onTap: () => _setPagesPerDay(p),
              ),
          ],
        ),
      ],
    );
  }

  Widget _learningSection(AppPalette palette, AppState state) {
    final learningUnit = _learningUnit;
    final count =
        state.config?.versesToLearnPerDay ?? defaultVersesToLearnPerDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(palette, SCheckIn.checkInApprentissage),
        const SizedBox(height: 8),
        if (learningUnit == null)
          OutlinedActionButton(
              icon: Icons.school_outlined,
              label: SCheckIn.checkInChoisirSourate,
              onTap: _pickLearningSourate)
        else ...[
          // Même carte que les unités de révision (`UnitRow`) : seuls
          // l'action de fin et le choix du nombre de versets diffèrent.
          UnitRow(
            unit: learningUnit,
            subtitle: _learning == null
                ? SCheckIn.checkInApprentissageDesc
                : '${_learning!.learnedCount}/${_learning!.totalVerses} ${S.versets}',
            trailingIcon: Icons.swap_horiz,
            onTrailing: _pickLearningSourate,
            onTap: _pickLearningSourate,
            footer: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in versesToLearnPresets)
                  PillChip(
                    label: SCheckIn.checkInVersetsAApprendre(n),
                    selected: n == count,
                    onTap: () => _setLearning(learningUnit.sourate, n),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _setLearning(null, count),
            child: Text(SCheckIn.checkInAucunApprentissage,
                style: TextStyle(fontSize: 12, color: palette.textMuted)),
          ),
        ],
      ],
    );
  }

  Widget _prayerSection(AppPalette palette) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sectionLabel(palette, SCheckIn.checkInPrieres),
              if (_lastPrayers != null)
                TextButton.icon(
                  onPressed: _applyLastPrayers,
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(_isYesterday ? S.commeHier : S.derniereSelection,
                      style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          Text(SCheckIn.checkInPrieresDesc,
              style: TextStyle(fontSize: 11, color: palette.textMuted)),
          const SizedBox(height: 10),
          PrayerSelector(
            selected: _prayers,
            onToggle: (p) => _setState(() {
              _prayers.contains(p) ? _prayers.remove(p) : _prayers.add(p);
            }),
            tahiyyatCount: _tahiyyatCount,
            onTahiyyatCountChanged: (n) => _setState(() => _tahiyyatCount = n),
          ),
        ],
      );

  void _applyLastPrayers() {
    if (_lastPrayers == null) return;
    // tahiyyatMasjid peut apparaître plusieurs fois — on compte les occurrences
    final tahiyyat = _lastPrayers!.where((p) => p.isTahiyyat).length;
    final others = _lastPrayers!.where((p) => !p.isTahiyyat).toSet();
    _setState(() {
      _prayers
        ..clear()
        ..addAll(others);
      _tahiyyatCount = tahiyyat;
    });
  }
}
