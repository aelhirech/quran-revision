part of 'ayah_facts_service.dart';

/// Rituel check-in/check-out (Phase 6 Sprint 2) — écritures/lectures
/// génériques sur `ayah_facts` (proposition du jour, bascules `reach`/
/// `needs_work`, scellement). Voir [AyahFactsService] pour le schéma partagé
/// (`_open`/`_userId`, accessibles ici via `part of`).
class AyahFactsRitual {
  /// Date la plus ancienne, STRICTEMENT avant aujourd'hui, dont le jour de
  /// révision n'est pas encore scellé (`checked_out = 0`), ou `null` si
  /// aucune. Sert à geter le moteur quotidien : tant qu'un jour est en
  /// attente, on ne génère pas le plan du jour suivant — `cyclePosition`
  /// n'a pas encore avancé pour ce jour-là, un nouveau plan proposerait les
  /// mêmes versets une seconde fois. Le filtre `date < aujourd'hui` est
  /// nécessaire : sans lui, le plan du jour tout juste proposé (encore
  /// `checked_out = 0` puisque non scellé) se compterait lui-même comme "en
  /// attente" — un jour non check-outé reste modifiable jusqu'au soir, ce
  /// n'est pas un rattrapage (voir cadrage, "Verrouillage").
  static Future<String?> pendingDate({required Riwaya riwaya}) async {
    final db = await AyahFactsService._open();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await db.rawQuery(
      'SELECT MIN(date) as d FROM ayah_facts '
      'WHERE riwaya = ? AND type = ? AND checked_out = 0 AND date < ?',
      [riwaya.name, AyahFactType.revise.name, today],
    );
    return rows.first['d'] as String?;
  }

  /// Écrit des unités de révision comme proposition du jour — `reach = 0,
  /// checked_out = 0`, pas encore confirmées. Utilisé à la fois par le
  /// moteur quotidien (plan initial) et par le check-in (ajout manuel d'une
  /// sourate/portion) : même écriture. [ConflictAlgorithm.ignore] — pas
  /// `replace` — la rend idempotente SANS écraser un `reach`/`needs_work` déjà
  /// posé sur un verset qui y figurait déjà (ex. deux appels concurrents à
  /// `ensureDayPlan`, ou un ré-ajout d'un verset déjà coché) ; `replace`
  /// remettrait silencieusement ces colonnes à leurs valeurs par défaut.
  static Future<void> proposeUnits(
      String date, Riwaya riwaya, List<RevisionUnit> units) async {
    if (units.isEmpty) return;
    final db = await AyahFactsService._open();
    final batch = db.batch();
    for (final unit in units) {
      for (int v = unit.verseStart; v <= unit.verseEnd; v++) {
        batch.insert(
          'ayah_facts',
          AyahFact(
            userId: AyahFactsService._userId,
            date: date,
            riwaya: riwaya,
            surahId: unit.sourate.id,
            ayahId: v,
            type: AyahFactType.revise,
          ).toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
    await batch.commit(noResult: true);
  }

  /// Retire une sourate/portion du plan du jour (check-in, bouton "×").
  static Future<void> removeFromDayPlan(
      String date, Riwaya riwaya, int surahId,
      {int? verseStart, int? verseEnd}) async {
    final db = await AyahFactsService._open();
    if (verseStart == null || verseEnd == null) {
      await db.delete('ayah_facts',
          where: 'date = ? AND riwaya = ? AND surah_id = ? AND type = ?',
          whereArgs: [date, riwaya.name, surahId, AyahFactType.revise.name]);
    } else {
      await db.delete('ayah_facts',
          where:
              'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
          whereArgs: [
            date,
            riwaya.name,
            surahId,
            verseStart,
            verseEnd,
            AyahFactType.revise.name
          ]);
    }
  }

  /// Efface la proposition non encore acquise d'un jour, pour la
  /// régénérer — l'utilisateur ajuste son rythme (révision) ou change de
  /// sourate/nombre de versets (apprentissage) au check-in. Ne touche jamais
  /// une ligne `reach = 1` : une progression déjà faite ne disparaît pas
  /// parce qu'on recalcule la proposition (voir CLAUDE.md § « Modèle de
  /// données central »). Même nature de suppression que
  /// [removeFromDayPlan] (retrait explicite du plan du jour), pas un
  /// "retour en arrière" d'un pas.
  static Future<void> clearDayProposal(String date, Riwaya riwaya,
      {AyahFactType type = AyahFactType.revise}) async {
    final db = await AyahFactsService._open();
    await db.delete('ayah_facts',
        where: 'date = ? AND riwaya = ? AND type = ? AND reach = 0',
        whereArgs: [date, riwaya.name, type.name]);
  }

  /// Comme [setReach], mais pour plusieurs unités en un seul aller-retour
  /// SQLite (`db.batch()`) — utilisé quand une manche PlanScreen complétée
  /// couvre plusieurs sourates/portions d'un coup (voir
  /// `AppState.markUnitsReached`).
  static Future<void> setReachForUnits(
      String date, Riwaya riwaya, List<RevisionUnit> units, bool reach) async {
    if (units.isEmpty) return;
    final db = await AyahFactsService._open();
    final batch = db.batch();
    for (final unit in units) {
      batch.update('ayah_facts', {'reach': reach ? 1 : 0},
          where:
              'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
          whereArgs: [
            date,
            riwaya.name,
            unit.sourate.id,
            unit.verseStart,
            unit.verseEnd,
            AyahFactType.revise.name
          ]);
    }
    await batch.commit(noResult: true);
  }

  /// Comme [setReach], mais pour une liste de versets précis d'une même
  /// sourate en un seul aller-retour — la portion à apprendre d'un jour
  /// n'est pas nécessairement contiguë (l'utilisateur peut avoir désappris
  /// un verset au milieu, voir `AppState._proposeLearning`), donc une plage
  /// `BETWEEN` ne suffit pas.
  static Future<void> setReachForVerses(String date, Riwaya riwaya, int surahId,
      List<int> ayahIds, bool reach,
      {required AyahFactType type}) async {
    if (ayahIds.isEmpty) return;
    final db = await AyahFactsService._open();
    final batch = db.batch();
    for (final ayahId in ayahIds) {
      batch.update('ayah_facts', {'reach': reach ? 1 : 0},
          where:
              'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id = ? AND type = ?',
          whereArgs: [date, riwaya.name, surahId, ayahId, type.name]);
    }
    await batch.commit(noResult: true);
  }

  /// Bascule `reach` ("fait"/"pas fait") pour une plage de versets — case à
  /// cocher du check-out, ou une rakaa cochée dans PlanScreen. [type] permet
  /// la même bascule sur la portion à *apprendre* du jour (rakaa
  /// d'apprentissage, confirmation au check-out) plutôt que de dupliquer un
  /// `setLearnReach` quasi identique à côté.
  static Future<void> setReach(String date, Riwaya riwaya, int surahId,
      int verseStart, int verseEnd, bool reach,
      {AyahFactType type = AyahFactType.revise}) async {
    final db = await AyahFactsService._open();
    await db.update('ayah_facts', {'reach': reach ? 1 : 0},
        where:
            'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
        whereArgs: [
          date,
          riwaya.name,
          surahId,
          verseStart,
          verseEnd,
          type.name
        ]);
  }

  /// Bascule `needs_work` ("à retravailler") pour un verset précis — écran
  /// détail du check-out, granularité verset (pas la sourate entière).
  static Future<void> setNeedsWork(String date, Riwaya riwaya, int surahId,
      int ayahId, bool needsWork) async {
    final db = await AyahFactsService._open();
    await db.update('ayah_facts', {'needs_work': needsWork ? 1 : 0},
        where: 'date = ? AND riwaya = ? AND surah_id = ? AND ayah_id = ? AND type = ?',
        whereArgs: [date, riwaya.name, surahId, ayahId, AyahFactType.revise.name]);
  }

  /// Pour chaque verset de [surahId] entre [verseStart] et [verseEnd] déjà
  /// révisé au moins une fois (`reach = 1`), sa date de dernière révision et
  /// son drapeau `needs_work` actuel sur CETTE date précise — un verset
  /// jamais révisé (aucune ligne `reach = 1`) est absent du résultat.
  ///
  /// Sert à flaguer "à retravailler" depuis le Récap (relecture hors rituel
  /// quotidien, `VerseBottomSheet`) : [setNeedsWork] n'accepte qu'une date
  /// explicite, et le jour courant n'a pas forcément de ligne pour un verset
  /// qu'on relit sans le réviser aujourd'hui — la date de sa dernière
  /// révision, elle, existe toujours pour un verset déjà acquis.
  static Future<Map<int, ({String date, bool needsWork})>> lastRevisionFlags(
      Riwaya riwaya, int surahId, int verseStart, int verseEnd) async {
    final db = await AyahFactsService._open();
    final rows = await db.rawQuery(
      'SELECT ayah_id, date, needs_work FROM ayah_facts outer_af '
      'WHERE riwaya = ? AND surah_id = ? AND type = ? AND reach = 1 '
      'AND ayah_id BETWEEN ? AND ? '
      'AND date = (SELECT MAX(date) FROM ayah_facts inner_af '
      'WHERE inner_af.riwaya = outer_af.riwaya '
      'AND inner_af.surah_id = outer_af.surah_id '
      'AND inner_af.ayah_id = outer_af.ayah_id '
      'AND inner_af.type = outer_af.type '
      'AND inner_af.reach = 1)',
      [riwaya.name, surahId, AyahFactType.revise.name, verseStart, verseEnd],
    );
    return {
      for (final row in rows)
        row['ayah_id'] as int: (
          date: row['date'] as String,
          needsWork: (row['needs_work'] as int) == 1,
        ),
    };
  }

  /// Both questions the check-out asks about a range, in ONE query: does it
  /// still have rows (kept at check-in), and are they all reached?
  ///
  /// They used to be two round-trips with a byte-identical `WHERE`, and the
  /// cycle now walks pages rather than surahs — that is several hundred
  /// sequential queries on a full check-out instead of a few dozen.
  ///
  /// `reached` is `false` both when nothing was done and when the range was
  /// removed at check-in ([removeFromDayPlan]); `exists` tells the two apart,
  /// which is exactly what `AppState._completedPagesFor` needs.
  static Future<({bool exists, bool reached})> rangeStatus(String date,
      Riwaya riwaya, int surahId, int verseStart, int verseEnd) async {
    final db = await AyahFactsService._open();
    final rows = await db.rawQuery(
      'SELECT COUNT(*) as total, SUM(reach) as reached FROM ayah_facts '
      'WHERE date = ? AND riwaya = ? AND surah_id = ? AND ayah_id BETWEEN ? AND ? AND type = ?',
      [date, riwaya.name, surahId, verseStart, verseEnd, AyahFactType.revise.name],
    );
    final total = rows.first['total'] as int? ?? 0;
    final reached = rows.first['reached'] as int? ?? 0;
    return (exists: total > 0, reached: total > 0 && total == reached);
  }

  /// Versets `reach = 1` du jour, par sourate — une seule requête (même
  /// principe de regroupement en Dart que [dayFacts]/`AyahFactsLearning.learnedVersesBySourate`)
  /// pour qu'`AppState.reachStatusFor` n'ait pas besoin d'une requête
  /// [rangeStatus] par unité affichée dans PlanScreen.
  static Future<Map<int, Set<int>>> reachedVersesToday(
      String date, Riwaya riwaya,
      {AyahFactType type = AyahFactType.revise}) async {
    final db = await AyahFactsService._open();
    final rows = await db.query('ayah_facts',
        columns: ['surah_id', 'ayah_id'],
        where: 'date = ? AND riwaya = ? AND type = ? AND reach = 1',
        whereArgs: [date, riwaya.name, type.name]);
    final result = <int, Set<int>>{};
    for (final row in rows) {
      result.putIfAbsent(row['surah_id'] as int, () => {}).add(row['ayah_id'] as int);
    }
    return result;
  }

  /// Scelle une journée : `checked_out = 1` pour ses lignes de révision.
  /// **Volontairement borné à `type = 'revise'`** : `checked_out` n'est lu
  /// que par [pendingDate], elle-même filtrée sur `revise`. L'élargir à
  /// `learn` ressemblerait à une décision de modèle sans en être une (aucun
  /// lecteur, et `AyahFactsLearning.learnVerses` écrit déjà `checked_out = 1`
  /// par construction) — si le gating du moteur quotidien doit un jour tenir
  /// compte de l'apprentissage, c'est [pendingDate] qu'il faut élargir en
  /// premier, pas cette écriture. `reach`/`needs_work` doivent déjà être à
  /// jour (voir [setReach]/[setNeedsWork], appliqués au fil des interactions
  /// du check-out) — chaque bascule précédente est déjà durablement écrite,
  /// un simple UPDATE suffit donc ici.
  static Future<void> sealDay(String date, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    await db.update('ayah_facts', {'checked_out': 1},
        where: 'date = ? AND riwaya = ? AND type = ?',
        whereArgs: [date, riwaya.name, AyahFactType.revise.name]);
  }

  /// La journée [date] a-t-elle déjà été scellée ? `false` s'il n'y a aucune
  /// ligne de révision ce jour-là — une journée sans plan n'est pas une
  /// journée clôturée. Sert au garde-fou de `AppState.checkOut` (le cycle
  /// n'avance qu'une fois par jour) et à l'état "au repos" de l'accueil,
  /// depuis que « Clôturer ma journée » permet de sceller le jour courant
  /// sans attendre le lendemain (Phase 9 Sprint 2).
  ///
  /// Prédicat **monotone** — « il existe une ligne scellée », pas « toutes
  /// les lignes le sont » : une journée peut redevenir mixte après son
  /// scellement (une ligne fraîche `checked_out = 0` écrite par
  /// [proposeUnits]), et un `MIN(checked_out)` répondrait alors « pas
  /// scellée », désarmant le garde-fou anti-double-comptage de `checkOut`
  /// exactement quand il sert. À ne pas confondre avec [pendingDate], qui
  /// pose la question inverse (« reste-t-il quelque chose à clôturer ? ») et
  /// doit, elle, rester sensible à ces lignes fraîches.
  static Future<bool> isDaySealed(String date, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    final rows = await db.rawQuery(
      'SELECT 1 FROM ayah_facts '
      'WHERE date = ? AND riwaya = ? AND type = ? AND checked_out = 1 LIMIT 1',
      [date, riwaya.name, AyahFactType.revise.name],
    );
    return rows.isNotEmpty;
  }

  /// Reconstruit le plan du jour en lignes groupées par sourate — une entrée
  /// par plage contiguë de versets écrite ce jour-là ([DayFactGroup]), pour
  /// l'affichage check-in/check-out et PlanScreen. Groupe en Dart plutôt
  /// qu'en SQL (même précédent que `AyahFactsLearning.learnedVersesBySourate`).
  static Future<List<DayFactGroup>> dayFacts(
      String date, Riwaya riwaya) async {
    final db = await AyahFactsService._open();
    final rows = await db.query('ayah_facts',
        columns: ['surah_id', 'ayah_id', 'reach', 'needs_work'],
        where: 'date = ? AND riwaya = ? AND type = ?',
        whereArgs: [date, riwaya.name, AyahFactType.revise.name],
        orderBy: 'surah_id, ayah_id');
    // One entry per CONTIGUOUS run, not one MIN..MAX range per surah: since
    // the cycle became a page list, a single day can hold two non-adjacent
    // fragments of the same surah (the cycle wrapping onto its own first
    // page). Collapsing them would show — and credit at check-out — every
    // verse in between, none of which was ever proposed.
    final groups = <DayFactGroup>[];
    List<Map<String, Object?>> run = [];
    int? runSurah;

    void flush() {
      if (run.isEmpty) return;
      groups.add(DayFactGroup(
        surahId: runSurah!,
        verseStart: run.first['ayah_id'] as int,
        verseEnd: run.last['ayah_id'] as int,
        reach: run.every((r) => (r['reach'] as int) == 1),
        needsWorkVerses: {
          for (final r in run)
            if ((r['needs_work'] as int) == 1) r['ayah_id'] as int,
        },
      ));
      run = [];
    }

    for (final row in rows) {
      final surah = row['surah_id'] as int;
      final ayah = row['ayah_id'] as int;
      final continues = run.isNotEmpty &&
          surah == runSurah &&
          ayah == (run.last['ayah_id'] as int) + 1;
      if (!continues) {
        flush();
        runSurah = surah;
      }
      run.add(row);
    }
    flush();
    return groups;
  }
}

/// Une sourate/portion du plan du jour, reconstruite depuis `ayah_facts`
/// (voir [AyahFactsRitual.dayFacts]) — pas un objet persisté séparément.
class DayFactGroup {
  final int surahId;
  final int verseStart;
  final int verseEnd;
  final bool reach; // true seulement si toute la plage est reach=1
  final Set<int> needsWorkVerses;

  const DayFactGroup({
    required this.surahId,
    required this.verseStart,
    required this.verseEnd,
    required this.reach,
    required this.needsWorkVerses,
  });
}
