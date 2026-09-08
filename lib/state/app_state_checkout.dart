part of 'app_state.dart';

// ─── Check-in/check-out ritual (Phase 6 Sprint 2) — `reach` tracking and
// sealing ───────────────────────────────────────────────────────────────
//
// Building/editing the day plan lives in `app_state_dayplan.dart`. This file
// covers what checks/unchecks a unit, and what seals the day and advances
// the cycle.

extension AppStateCheckOut on AppState {
  /// Marque `reach` (par défaut `true`) en batch pour [units] — soit une
  /// manche PlanScreen complétée (date implicite : aujourd'hui, `reach`
  /// toujours vrai), soit la clôture d'un CheckOutScreen ([date] explicite) :
  /// `reach: true` pour confirmer "fait par défaut", `reach: false` pour
  /// annuler explicitement une unité déjà à `reach=1` (ex. cochée par erreur
  /// plus tôt dans PlanScreen) — voir CLAUDE.md § « Modèle de données
  /// central » : annuler une progression repasse `reach` à 0, jamais un
  /// simple no-op. N'avance jamais `cyclePosition` elle-même (voir
  /// [checkOut]) ; pas de `notifyListeners` ici, laissé aux appelants qui
  /// enchaînent d'autres écritures avant de notifier une seule fois pour
  /// toute l'opération.
  Future<void> markUnitsReached(List<RevisionUnit> units,
      {String? date, bool reach = true}) async {
    await AyahFactsService.setReachForUnits(date ?? todayStr, _riwaya, units, reach);
  }

  /// Bascule "fait/pas fait" pour une rakaa de PlanScreen — remplace
  /// l'ancien état en mémoire/SharedPreferences (`_checkedRakaas`) par une
  /// écriture directe dans `ayah_facts` pour aujourd'hui (voir [setUnitReach]
  /// pour une date arbitraire). Si [unit] est assigné à plusieurs rakaas de
  /// la manche (pénurie de matière, cf. `RevisionEngine._padCyclically`),
  /// cocher l'une coche automatiquement les autres — `reach` est une vérité
  /// par verset/jour, pas par rakaa, comportement voulu.
  /// [learning] cible la rakaa d'apprentissage (lignes `type='learn'`) au
  /// lieu de la révision — c'est le même geste ("j'ai fait cette rakaa") sur
  /// les deux natures de contenu.
  Future<void> toggleTodayUnitReach(RevisionUnit unit, bool reach,
      {bool learning = false}) async {
    if (!learning) return setUnitReach(todayStr, unit, reach);
    // La portion à apprendre n'est pas forcément contiguë (un verset du
    // milieu peut avoir été appris en avance, ou désappris) : on écrit la
    // liste exacte des versets proposés, pas la plage `BETWEEN` qui
    // engloberait des versets sans ligne en base.
    final plan = await learningPlanFor(todayStr);
    if (plan == null) return;
    await markLearnVerses(todayStr, plan.sourate.id, plan.ayahIds, reach);
    _notify();
  }

  /// Statut `reach` d'aujourd'hui pour chaque unité unique de [units] — une
  /// seule requête ([AyahFactsService.reachedVersesToday]), le résultat
  /// exact par plage étant recalculé en Dart (pas par sourate comme
  /// [dayUnitsWithStatus], qui agrégerait à tort deux plages distinctes de la
  /// même sourate assignées à des rakaas différents). Consommé par
  /// PlanScreen pour l'état "coché" de chaque rakaa.
  Future<Map<RevisionUnit, bool>> reachStatusFor(Iterable<RevisionUnit> units,
      {bool learning = false}) async {
    final reachedByVerse = await AyahFactsService.reachedVersesToday(
        todayStr, _riwaya,
        type: learning ? AyahFactType.learn : AyahFactType.revise);
    // Côté apprentissage, la vérité est la liste des versets réellement
    // proposés — pas tous ceux de la plage : une portion à trous
    // ([2, 4, 5]) ne serait sinon jamais considérée comme faite, le verset 3
    // n'ayant aucune ligne à passer à `reach = 1`.
    final learnVerses =
        learning ? (await learningPlanFor(todayStr))?.ayahIds : null;
    bool isReached(RevisionUnit unit) {
      final verses = learnVerses ??
          List.generate(unit.verseCount, (i) => unit.verseStart + i);
      return verses.isNotEmpty &&
          verses.every(
              (v) => reachedByVerse[unit.sourate.id]?.contains(v) ?? false);
    }

    return {for (final unit in units.toSet()) unit: isReached(unit)};
  }

  /// Bascule "à retravailler" pour un verset précis — écran détail du
  /// check-out, granularité verset (pas la sourate entière).
  Future<void> setVerseNeedsWork(
      String date, int surahId, int ayahId, bool needsWork) async {
    await AyahFactsService.setNeedsWork(date, _riwaya, surahId, ayahId, needsWork);
    _notify();
  }

  /// Bascule "fait/pas fait" pour une sourate/portion du check-out — ou, si
  /// [learning], pour une portion à apprendre (`type='learn'`).
  Future<void> setUnitReach(String date, RevisionUnit unit, bool reach,
      {bool learning = false}) async {
    await AyahFactsService.setReach(date, _riwaya, unit.sourate.id,
        unit.verseStart, unit.verseEnd, reach,
        type: learning ? AyahFactType.learn : AyahFactType.revise);
    _notify();
  }

  /// How many cycle PAGES day [date] actually completed, starting from
  /// `selection.cyclePosition` — this is what advances the cursor (the full
  /// business rule lives on [checkOut] and in `CLAUDE.md`).
  ///
  /// Counting does not stop at what the engine had proposed: it carries on
  /// into the NEXT pages of the cycle, so declaring extra work moves the
  /// cursor. A page beyond the proposal only counts if the user actually
  /// declared it that day, otherwise the cursor would skip never-revised
  /// content.
  Future<int> _completedPagesFor(String date, DaySelection selection) async {
    final cycle = RevisionEngine.buildCycle(
      config: _config!,
      pageMetadata: PageMetadataService.pageMetadataFor(_riwaya),
    );
    final proposedCount = selection.groups.length;
    int pagesCompleted = 0;
    for (int step = 0; step < cycle.length; step++) {
      final group = cycle[(selection.cyclePosition + step) % cycle.length];
      bool anyExists = false;
      for (final unit in group) {
        final status = await AyahFactsService.rangeStatus(
            date, _riwaya, unit.sourate.id, unit.verseStart, unit.verseEnd);
        if (!status.exists) continue; // retirée au check-in — ne bloque pas
        anyExists = true;
        // Unité présente mais pas faite : le groupe, et toute la suite, bloque.
        if (!status.reached) return pagesCompleted;
      }
      if (!anyExists) {
        // Aucune ligne pour ce groupe. Dans la proposition du jour, c'est un
        // retrait au check-in : ni compté ni bloquant. Au-delà, c'est
        // simplement du contenu non fait : le cycle s'arrête là.
        if (step < proposedCount) continue;
        return pagesCompleted;
      }
      pagesCompleted++;
    }
    return pagesCompleted;
  }

  /// Scelle la journée [date] (check-out) : verrouille ses lignes et fait
  /// avancer le cycle une seule fois pour toute la journée, à partir des
  /// GROUPES proposés par le moteur qui ont effectivement `reach=1` (dans
  /// l'ordre — même logique que la déclaration partielle historique de
  /// PlanScreen : un ajout hors-sélection au check-in alimente l'historique/
  /// la fraîcheur mais ne fait pas avancer `cyclePosition` au-delà de ce que
  /// le moteur avait initialement proposé ce jour-là — le cadrage n'a pas
  /// tranché de règle plus précise pour les ajouts hors-cycle, voir
  /// CHANGELOG). `cyclePosition` avance par GROUPE complété
  /// (`DaySelection.groups`), pas par unité individuelle : plusieurs courtes
  /// sourates qui partagent la même page réelle du mushaf forment un seul
  /// groupe/une seule position de cycle (voir cadrage "regroupement par page
  /// partagée", 2026-09-05) — les compter une par une désynchroniserait
  /// `cyclePosition` de `cycleTotal` (qui compte des groupes). Au sein d'un
  /// groupe, une unité entièrement retirée au check-in ([removeFromDayPlan])
  /// n'a plus aucune ligne en base : elle est ignorée (ni comptée ni
  /// bloquante) — seule une unité *présente* mais non faite bloque le groupe
  /// (et arrête le comptage des groupes suivants), sans quoi elle romprait à
  /// tort le comptage des groupes suivants réellement complétés (bug trouvé
  /// en revue de code). Un groupe dont TOUTES les unités ont été retirées est
  /// lui-même ignoré (ni compté ni bloquant), pour la même raison.
  ///
  /// **Idempotent sur le cycle** (Phase 9 Sprint 2) : re-clôturer une journée
  /// déjà scellée réécrit les `reach` corrigés mais ne fait plus avancer
  /// `cyclePosition` — voir le commentaire dans le corps. Retourne `true` si
  /// le cycle vient de boucler (milestone à afficher côté écran).
  Future<bool> checkOut(String date) async {
    if (_config == null) return false;
    // Passe moteur (CPU pur) et lecture SQLite indépendantes — démarrées
    // ensemble plutôt qu'en série.
    final sealedF = AyahFactsService.isDaySealed(date, _riwaya);
    final selection = _selection;
    // Une journée déjà scellée peut être re-clôturée : « Clôturer ma journée »
    // (Phase 9 Sprint 2) n'empêche pas de relancer une manche derrière, et le
    // check-out qui suivrait scellerait le même jour une seconde fois. Les
    // corrections de `reach` continuent de s'écrire normalement, mais le
    // cycle ne doit avancer qu'une seule fois pour un jour donné — sinon le
    // curseur sauterait du contenu jamais révisé, exactement ce que le
    // garde-fou de [_completedPagesFor] cherche à éviter.
    final pagesCompleted =
        await sealedF ? 0 : await _completedPagesFor(date, selection);
    final cycleWraps = pagesCompleted > 0 &&
        selection.cycleTotal > 0 &&
        (_cyclePosition + pagesCompleted) >= selection.cycleTotal;
    _pendingDate = null;
    _closedDate = date;
    _todaySession = null;
    // Écritures indépendantes (table ayah_facts, prefs, cycle) — lancées en
    // parallèle plutôt qu'en série.
    await Future.wait([
      AyahFactsService.sealDay(date, _riwaya),
      refreshFreshness(notify: false),
      StorageService.clearActivePrayers(_riwaya),
      advanceCycle(pagesCompleted, selection.cycleTotal, notify: false),
    ]);
    // Après le scellement seulement : une sourate dont le dernier verset
    // vient d'être confirmé appris rejoint la révision (voir
    // [handOffLearnedSurahs]).
    await handOffLearnedSurahs(notify: false);
    _notify(); // seul notify de toute l'opération
    return cycleWraps;
  }
}
