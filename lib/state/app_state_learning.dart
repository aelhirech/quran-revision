part of 'app_state.dart';

// ─── Apprentissage du jour (Phase 9) ─────────────────────────────────────
//
// Même modèle que la révision : les versets à apprendre sont des lignes
// `ayah_facts` datées (`type='learn'`, `reach=0` visé → `reach=1` acquis),
// jamais un état tenu en parallèle. La dernière rakaa du plan du jour les
// fait réciter, le check-out confirme lesquels sont réellement acquis.

extension AppStateLearning on AppState {
  /// Sourates dont la mémorisation est commencée mais pas terminée —
  /// reconstruites depuis `ayah_facts` (`type='learn'`).
  Future<List<LearningProgress>> learningProgressList() async =>
      AyahFactsService.loadMainLearningProgress(
          riwaya: _riwaya, sourates: _sourates);

  /// Sourate en cours d'apprentissage, ou `null`. Une seule à la fois en
  /// pratique (c'est le check-in qui en démarre une), mais changer de
  /// sourate en cours de route en laisse plusieurs inachevées : on retient
  /// la **plus récemment démarrée**, celle sur laquelle l'utilisateur
  /// travaille aujourd'hui — pas la première que renvoie SQLite, dont
  /// l'ordre ne veut rien dire.
  Future<LearningProgress?> learningInProgress() async {
    LearningProgress? latest;
    for (final p in await learningProgressList()) {
      if (p.isComplete) continue;
      if (latest == null || p.startDate.isAfter(latest.startDate)) latest = p;
    }
    return latest;
  }

  /// Prochains [count] versets non encore acquis de [sourate], proposés pour
  /// aujourd'hui — règle partagée avec l'écran de pratique
  /// (`LearningProgress.nextBlock`). [progress] évite une relecture quand
  /// l'appelant vient déjà de charger la progression de cette sourate.
  Future<void> _proposeLearning(Sourate sourate, int count,
      {LearningProgress? progress}) async {
    final resolved = progress ??
        LearningProgress(
          sourate: sourate,
          learnedVerses: await AyahFactsService.learnedVersesForSourate(
              riwaya: _riwaya, surahId: sourate.id),
          startDate: DateTime.now(),
        );
    await AyahFactsService.proposeLearnVerses(
        todayStr, _riwaya, sourate.id, resolved.nextBlock(count));
  }

  /// Portion à apprendre aujourd'hui (dernière rakaa du plan du jour), ou
  /// `null` si l'utilisateur n'apprend rien en ce moment. **Dérivée à la
  /// demande**, jamais mise en cache dans un champ : c'est exactement l'état
  /// parallèle à `ayah_facts` que CLAUDE.md interdit (précédent
  /// `_checkedRakaas`) — un cache aurait dû être rafraîchi par les 4 écrivains
  /// de lignes `learn`, dont `deleteLearnFacts` appelé depuis le Récap.
  Future<RevisionUnit?> todayLearningUnit() async {
    final plan = await learningPlanFor(todayStr);
    if (plan == null) return null;
    // `learnPlanFor` trie par `ayah_id`, donc first/last sont bien min/max.
    return RevisionUnit(
      sourate: plan.sourate,
      verseStart: plan.ayahIds.first,
      verseEnd: plan.ayahIds.last,
      isWhole: plan.ayahIds.first == 1 &&
          plan.ayahIds.last == plan.sourate.verses,
    );
  }

  /// Check-in : quelle sourate apprendre aujourd'hui et combien de versets.
  /// [sourate] `null` = ne rien apprendre aujourd'hui. [count] devient aussi
  /// le nouveau défaut proposé les jours suivants
  /// (`UserConfig.versesToLearnPerDay`).
  Future<void> setLearningForToday(Sourate? sourate, int count) async {
    if (_config == null) return;
    if (count != _config!.versesToLearnPerDay) {
      _config = _config!.copyWith(versesToLearnPerDay: count);
      await StorageService.saveConfig(_config!, _riwaya);
    }
    // Seules les lignes encore `reach=0` sont effacées — un verset déjà
    // acquis aujourd'hui ne disparaît pas parce qu'on réajuste la portion.
    await AyahFactsService.clearDayProposal(todayStr, _riwaya,
        type: AyahFactType.learn);
    if (sourate != null) await _proposeLearning(sourate, count);
    _notify();
  }

  /// Check-out : déclarer un verset **appris en plus** le jour [date] —
  /// ajoute le prochain verset non encore acquis de la sourate en cours
  /// d'apprentissage à la portion de ce jour. Sans effet s'il n'y a pas de
  /// portion ce jour-là, ou si la sourate est déjà entièrement mémorisée.
  Future<void> extendLearningForDate(String date) async {
    final plan = await learningPlanFor(date);
    if (plan == null) return;
    final learned = await AyahFactsService.learnedVersesForSourate(
        riwaya: _riwaya, surahId: plan.sourate.id);
    final taken = {...learned, ...plan.ayahIds};
    for (int v = 1; v <= plan.sourate.verses; v++) {
      if (taken.contains(v)) continue;
      await AyahFactsService.proposeLearnVerses(
          date, _riwaya, plan.sourate.id, [v]);
      break;
    }
    _notify();
  }

  /// Portion à apprendre proposée le jour [date] (check-out d'un jour en
  /// attente, ou aujourd'hui via [todayLearningUnit]), résolue en `Sourate` —
  /// `null` si l'utilisateur n'apprenait rien ce jour-là. Les versets sont
  /// rendus tels quels (liste, pas une plage) : la portion d'un jour n'est
  /// pas forcément contiguë si un verset du milieu a été appris en avance.
  /// `reachedVerses` est remonté pour que le check-out d'un jour DÉJÀ scellé
  /// puisse repartir des exceptions déclarées la première fois, au lieu de
  /// tout recocher par défaut (voir [dayUnitsWithStatus]).
  Future<({Sourate sourate, List<int> ayahIds, Set<int> reachedVerses})?>
      learningPlanFor(String date) async {
    final plan = await AyahFactsService.learnPlanFor(date, _riwaya);
    final sourate = plan == null ? null : _sourateById(plan.surahId);
    if (plan == null || sourate == null || plan.ayahIds.isEmpty) return null;
    return (
      sourate: sourate,
      ayahIds: plan.ayahIds,
      reachedVerses: plan.reachedVerses,
    );
  }

  /// Confirme (ou annule) l'acquisition de versets appris le jour [date] —
  /// check-out, en deux batchs (appris / à continuer). Annuler écrit
  /// explicitement `reach = 0` plutôt que de s'abstenir : la ligne peut déjà
  /// être à 1 (rakaa d'apprentissage cochée dans PlanScreen), voir CLAUDE.md
  /// § « Modèle de données central ».
  Future<void> markLearnVerses(
      String date, int surahId, List<int> ayahIds, bool learned) async {
    await AyahFactsService.setReachForVerses(
        date, _riwaya, surahId, ayahIds, learned,
        type: AyahFactType.learn);
  }

  /// Toute sourate entièrement mémorisée bascule automatiquement dans la
  /// sélection de révision et quitte l'apprentissage — « à la fin de
  /// l'apprentissage d'une sourate celle-ci devient à réviser » (cadrage
  /// Phase 9). Remplace l'ancien bouton manuel « Ajouter à la révision » de
  /// l'onglet Apprendre (supprimé). Retourne les sourates qui viennent de
  /// basculer, pour que l'appelant puisse le signaler à l'utilisateur.
  /// Appelé au check-out (avec `notify: false`, qui notifie lui-même une
  /// seule fois pour toute l'opération) et au retour de l'écran de pratique.
  ///
  /// La sourate rejoint `selections` **sans** passer par [saveConfig], qui
  /// remettrait `cyclePosition` à 0 : une sourate fraîchement mémorisée
  /// s'ajoute au cycle en cours, elle n'invalide pas la position déjà
  /// atteinte dans les autres.
  Future<List<Sourate>> handOffLearnedSurahs({bool notify = true}) async {
    if (_config == null) return const [];
    final handed = <Sourate>[];
    for (final p in await learningProgressList()) {
      // Déjà basculée lors d'un check-out précédent : ni ré-ajoutée, ni
      // re-signalée. C'est ce test — et non la suppression des faits
      // `learn` — qui rend la bascule idempotente : ces faits sont la trace
      // de mémorisation qui alimente « Sourates mémorisées » (Récap,
      // Réglages), les effacer remettrait ce compteur à 0 pour toujours.
      if (!p.isComplete ||
          _config!.selections.any((s) => s.sourate.id == p.sourate.id)) {
        continue;
      }
      _config = _config!.copyWith(
          selections: [..._config!.selections, SourateSelection.whole(p.sourate)]);
      await StorageService.saveConfig(_config!, _riwaya);
      handed.add(p.sourate);
    }
    if (notify && handed.isNotEmpty) _notify();
    return handed;
  }
}
