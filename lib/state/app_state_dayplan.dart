part of 'app_state.dart';

// ─── Check-in/check-out ritual (Phase 6 Sprint 2) — building/editing the day
// plan ──────────────────────────────────────────────────────────────────
//
// The daily engine is the only source of the day plan: it writes proposed
// units directly into `ayah_facts` (see cadrage, "Moteur quotidien — source
// unique de vérité"). Check-in edits these rows, PlanScreen displays/spreads
// them across rakaas. Sealing (`checkOut`) and `reach` tracking live in
// `app_state_checkout.dart`.

extension AppStateDayPlan on AppState {
  RevisionUnit? _unitFor(DayFactGroup g) {
    final s = _sourateById(g.surahId);
    if (s == null) return null;
    return RevisionUnit(
      sourate: s,
      verseStart: g.verseStart,
      verseEnd: g.verseEnd,
      isWhole: g.verseStart == 1 && g.verseEnd == s.verses,
    );
  }

  /// Unités du plan du jour (date passée, `todayStr` par défaut), telles que
  /// validées au check-in — reconstruites depuis `ayah_facts`, jamais
  /// recalculées indépendamment (voir cadrage).
  Future<List<RevisionUnit>> dayUnits({String? date}) async {
    final groups = await AyahFactsService.dayFacts(date ?? todayStr, _riwaya);
    return groups.map(_unitFor).whereType<RevisionUnit>().toList();
  }

  /// Comme [dayUnits], avec les versets flagués "à retravailler" de chaque
  /// unité (`needsWorkVerses`) — c'est cette version que consomme
  /// CheckOutScreen. Ne renvoie plus `reach` (Sprint 7) : CheckOutScreen
  /// affiche tout comme "fait" par défaut, indépendamment de la valeur
  /// persistée (voir Backlog "Check-out : reach fait par défaut",
  /// 2026-09-04) — le `reach` en base ne sert plus qu'à [checkOut] lui-même.
  Future<List<({RevisionUnit unit, Set<int> needsWorkVerses})>> dayUnitsWithStatus(
      {String? date}) async {
    final groups = await AyahFactsService.dayFacts(date ?? todayStr, _riwaya);
    return [
      for (final g in groups)
        if (_unitFor(g) case final unit?)
          (unit: unit, needsWorkVerses: g.needsWorkVerses),
    ];
  }

  /// Aperçu pur (aucune écriture) de ce que le moteur quotidien proposerait
  /// s'il tournait maintenant — utilisé par le check-out multi-jours (Partie
  /// 2, "ajouter aussi aujourd'hui") pour montrer un aperçu avant de sceller.
  /// Même appel que [ensureDayPlan] fait réellement, exposé ici pour que les
  /// écrans n'importent jamais `RevisionEngine` directement.
  Future<List<RevisionUnit>> previewTodayUnits() async {
    if (_config == null) return const [];
    return _selection.units;
  }

  /// Position/total du cycle en cours (nombre de groupes `RevisionEngine`),
  /// à afficher (bandeau HomeScreen, carte cycle RecapScreen) — dérivés de la
  /// même [_selectionForAsync] que le plan du jour (`DailySession`,
  /// PlanScreen), pour que les 3 écrans ne recalculent plus chacun leur
  /// propre `RevisionEngine.buildDayUnits(...)` (source de divergence
  /// silencieuse, retour TestFlight 2026-09-01 sur les chiffres du
  /// récapitulatif).
  Future<DaySelection> getDaySelectionForToday() async => _selection;

  /// Point d'entrée du moteur quotidien — à appeler à l'ouverture/reprise de
  /// l'app (voir ShellScreen). Gated sur un éventuel jour en attente
  /// STRICTEMENT antérieur à aujourd'hui (voir `AyahFactsService.pendingDate`) :
  /// tant qu'il n'est pas scellé, aucun nouveau plan n'est généré (sinon
  /// `cyclePosition` n'aurait pas encore avancé pour ce jour-là, et le
  /// nouveau plan proposerait les mêmes versets une seconde fois).
  ///
  /// Depuis la Phase 9, propose aussi les versets à **apprendre** du jour
  /// (sourate déjà en cours, `config.versesToLearnPerDay` versets) — le
  /// check-in confirme ou ajuste les deux propositions, il ne les crée pas.
  Future<void> ensureDayPlan({bool notify = true}) async {
    if (_config == null) return;
    final today = todayStr;
    // Deux lectures indépendantes — démarrées ensemble, comme le bloc
    // ci-dessous : c'est le chemin d'ouverture de l'app.
    final pendingF = AyahFactsService.pendingDate(riwaya: _riwaya);
    final sealedF = AyahFactsService.isDaySealed(today, _riwaya);
    _pendingDate = await pendingF;
    _closedDate = await sealedF ? today : null;
    if (_pendingDate == null) {
      // Lectures indépendantes démarrées ensemble plutôt qu'en série — c'est
      // le chemin d'ouverture de l'app (ShellScreen.initState).
      final existingF = AyahFactsService.dayFacts(today, _riwaya);
      final learnPlanF = AyahFactsService.learnPlanFor(today, _riwaya);
      final activePrayersF = StorageService.loadActivePrayers(_riwaya);
      // Le plan du jour n'est généré qu'une fois par jour — la proposition
      // d'apprentissage est gatée sur ce même moment, pas seulement sur
      // « aucune ligne learn aujourd'hui » : sinon « Je n'apprends rien
      // aujourd'hui » (check-in) serait silencieusement annulé à la
      // prochaine ouverture de l'app, qui reproposerait la même portion.
      // Cas limite connu : sans aucune sourate en révision, `proposeUnits`
      // n'écrit rien, la journée reste vue comme neuve et le refus est
      // reproposé à chaque ouverture — sans conséquence sur les données.
      if ((await existingF).isEmpty) {
        await AyahFactsService.proposeUnits(
            today, _riwaya, _selection.units);
        if (await learnPlanF == null) {
          final inProgress = await learningInProgress();
          if (inProgress != null) {
            await _proposeLearning(
                inProgress.sourate, _config!.versesToLearnPerDay,
                progress: inProgress);
          }
        }
      }
      // Reprend la manche en cours si l'app a redémarré après un début de
      // check-in/PlanScreen le même jour (prières déjà choisies).
      final activePrayers = await activePrayersF;
      if (activePrayers != null && activePrayers.isNotEmpty) {
        await buildTodaySession(activePrayers, notify: false);
      }
    }
    if (notify) _notify();
  }

  /// Check-in (et ligne « Rythme » des Réglages) : ajuste le budget de
  /// pages/jour et régénère la proposition de révision du jour en conséquence
  /// (les lignes déjà `reach=1` sont conservées, voir
  /// `AyahFactsService.clearDayProposal`).
  ///
  /// **Sauf si la journée est déjà clôturée** : depuis « Clôturer ma journée »
  /// (Phase 9 Sprint 2), aujourd'hui peut être scellé alors qu'il est encore
  /// aujourd'hui. Y réécrire une proposition fraîche (`checked_out = 0`)
  /// rouvrirait un jour déjà compté — il redeviendrait « en attente » demain,
  /// et son second check-out ferait avancer le cycle une seconde fois sur du
  /// contenu déjà crédité. Le nouveau rythme est persisté quand même : il
  /// s'appliquera au plan de demain.
  Future<void> setPagesPerDay(int pagesPerDay) async {
    if (_config == null || _config!.pagesPerDay == pagesPerDay) return;
    _config = _config!.copyWith(pagesPerDay: pagesPerDay);
    await StorageService.saveConfig(_config!, _riwaya);
    if (!todayClosed) {
      final today = todayStr;
      await AyahFactsService.clearDayProposal(today, _riwaya);
      await AyahFactsService.proposeUnits(
          today, _riwaya, _selection.units);
      // Une manche déjà répartie en rakaas porterait des unités qui viennent
      // d'être effacées de la table — ses cases cochées reviendraient en
      // arrière sans explication. On la referme, comme `saveConfig` le fait
      // quand la sélection de sourates change.
      _todaySession = null;
      await StorageService.clearActivePrayers(_riwaya);
    }
    _notify();
  }

  /// Ajoute une sourate/portion au plan du jour depuis le check-in.
  /// [date] par défaut aujourd'hui (check-in). Le check-out la passe
  /// explicitement pour déclarer une sourate **révisée en plus** ce jour-là :
  /// même écriture, l'unité rejoint simplement le plan d'une journée passée,
  /// où le "fait par défaut" du check-out la confirmera à la clôture. Comme
  /// tout ajout hors-sélection, elle alimente historique et fraîcheur mais
  /// ne fait pas avancer `cyclePosition` au-delà de ce que le moteur avait
  /// proposé (voir [checkOut]).
  Future<void> addToDayPlan(RevisionUnit unit, {String? date}) async {
    await AyahFactsService.proposeUnits(date ?? todayStr, _riwaya, [unit]);
    _notify();
  }

  /// Retire une sourate du plan du jour depuis le check-in.
  Future<void> removeFromDayPlan(int surahId) async {
    await AyahFactsService.removeFromDayPlan(todayStr, _riwaya, surahId);
    _notify();
  }

  /// Étend d'un verset la portée d'une sourate du plan du jour (chip "+" de
  /// l'écran détail du check-in).
  Future<void> extendDayPlanVerse(int surahId, int newVerse) async {
    final s = _sourateById(surahId);
    if (s == null) return;
    await AyahFactsService.proposeUnits(todayStr, _riwaya,
        [RevisionUnit(sourate: s, verseStart: newVerse, verseEnd: newVerse, isWhole: false)]);
    _notify();
  }

  /// Construit (ou reconstruit) le plan du jour réparti en rakaas pour les
  /// prières données — répartit les unités déjà validées au check-in
  /// ([dayUnits]), ne les régénère pas. Persiste la sélection de prières
  /// pour survivre à un redémarrage de l'app avant la fin de la manche.
  Future<void> buildTodaySession(List<Prayer> prayersAlone,
      {bool notify = true}) async {
    if (_config == null || prayersAlone.isEmpty) return;
    // Trois lectures indépendantes (sélection du cycle, unités du jour,
    // portion à apprendre) démarrées ensemble plutôt qu'en série.
    final selection = _selection;
    final unitsF = dayUnits();
    final learningF = todayLearningUnit();
    final units = await unitsF;
    final plan = RevisionEngine.distributeToRakaas(
      units: units,
      prayersAlone: prayersAlone,
      learningUnit: await learningF,
    );
    // Units the layout could not place. Only possible when there are more
    // units than reciting rakaas — in that case `distributeToRakaas` assigns
    // them whole, so comparing by value is exact. When it subdivides instead
    // (fewer units than rakaas), nothing is ever left out.
    final assigned = {
      for (final pp in plan)
        for (final r in pp.rakaas)
          if (r.unit != null && !r.isLearning) r.unit!,
    };
    final outside = [
      for (final u in units)
        if (!assigned.contains(u)) u,
    ];
    _todaySession = DailySession(
      date: DateTime.now(),
      prayersAlone: prayersAlone,
      plan: plan,
      // Sur les unités réellement retenues (`dayUnits()`, donc après édition
      // au check-in), pas sur la proposition d'origine de `selection`.
      pagesToday: RevisionEngine.pagesOf(
          units, PageMetadataService.pageMetadataFor(_riwaya)),
      cyclePosition: selection.cyclePosition,
      cycleTotal: selection.cycleTotal,
      outsidePrayers: outside,
    );
    // `saveActivePrayers` = reprendre la manche en cours après un
    // redémarrage ; `saveLastSessionPrayers` = alimenter « reprendre les
    // prières d'hier » au prochain check-in. Écrit ici, au moment où les
    // prières sont choisies, plutôt qu'à la fin d'une manche « complétée » —
    // depuis la Phase 9 Sprint 2 il n'y a plus de complétion de manche, la
    // journée se termine au check-out (voir `PlanScreen.onCloturer`).
    await Future.wait([
      StorageService.saveActivePrayers(prayersAlone, _riwaya),
      StorageService.saveLastSessionPrayers(
          DateTime.now(), prayersAlone, _riwaya),
    ]);
    if (notify) _notify();
  }
}
