import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/cycle_anchor.dart';
import 'package:quran_revision/core/revision_engine.dart';
import 'package:quran_revision/models/revision_unit.dart';
import 'package:quran_revision/models/riwaya.dart';
import 'package:quran_revision/models/sourate.dart';
import 'package:quran_revision/models/sourate_selection.dart';
import 'package:quran_revision/models/user_config.dart';

/// US-29: when a learned surah is widened or added, `cyclePosition` follows
/// the verse it pointed to, not its index.

Sourate _sourate(int id, int verses) =>
    Sourate(id: id, nameAr: 'س$id', nameFr: 'S$id', verses: verses, words: 50);

final _a = _sourate(1, 3);
final _s = _sourate(2, 6);
final _b = _sourate(3, 3);
final _c = _sourate(4, 3);
final _x = _sourate(5, 3);
final _y = _sourate(6, 5);

// Surah S spans two pages (11, 12); Y starts on page 50, shared with X.
final _pages = {
  1: {1: 1, 2: 1, 3: 1},
  2: {1: 11, 2: 11, 3: 11, 4: 12, 5: 12, 6: 12},
  3: {1: 20, 2: 20, 3: 20},
  4: {1: 30, 2: 30, 3: 30},
  5: {1: 50, 2: 50, 3: 50},
  6: {1: 50, 2: 50, 3: 51, 4: 51, 5: 51},
};

List<List<RevisionUnit>> _cycle(List<SourateSelection> selections) =>
    RevisionEngine.buildCycle(
      config: UserConfig(
        selections: selections,
        pagesPerDay: 1,
        startDate: DateTime(2026, 1, 1),
        riwaya: Riwaya.hafs,
        shuffleEnabled: false,
      ),
      pageMetadata: _pages,
    );

SourateSelection _range(Sourate s, int start, int end) =>
    SourateSelection(sourate: s, verseStart: start, verseEnd: end);

void main() {
  test('une sourate élargie avant le curseur ne le décale pas', () {
    final oldCycle = _cycle([
      SourateSelection.whole(_a),
      _range(_s, 1, 3),
      SourateSelection.whole(_b),
      SourateSelection.whole(_c),
    ]);
    final newCycle = _cycle([
      SourateSelection.whole(_a),
      SourateSelection.whole(_s),
      SourateSelection.whole(_b),
      SourateSelection.whole(_c),
    ]);
    expect(oldCycle[2].first.sourate.id, _b.id);
    expect(newCycle.length, 5, reason: 'A, S p.11, S p.12, B, C');

    final pos = reanchorCursor(oldCycle, 2, newCycle);

    expect(pos, 3);
    expect(newCycle[pos!].first.sourate.id, _b.id,
        reason: "garder l'index 2 pointerait S p.12 et sauterait B");
  });

  test('une sourate ajoutée en fin laisse le curseur sur sa page', () {
    final oldCycle =
        _cycle([SourateSelection.whole(_a), SourateSelection.whole(_b)]);
    final newCycle = _cycle([
      SourateSelection.whole(_a),
      SourateSelection.whole(_b),
      SourateSelection.whole(_c),
    ]);

    expect(reanchorCursor(oldCycle, 1, newCycle), 1);
  });

  test('null quand l\'ancien cycle est vide', () {
    expect(reanchorCursor([], 0, _cycle([SourateSelection.whole(_a)])),
        isNull);
  });

  // Characterises the rare E2 case accepted by US-29: no rule fixes it.
  test(
      'page partagée qui se sépare : ancre retrouvée, le fragment voisin '
      'revient après le curseur', () {
    final oldCycle = _cycle([
      SourateSelection.whole(_a),
      SourateSelection.whole(_x),
      _range(_y, 1, 2),
    ]);
    final newCycle = _cycle([
      SourateSelection.whole(_a),
      SourateSelection.whole(_x),
      SourateSelection.whole(_y),
    ]);
    expect(oldCycle[1].map((u) => u.sourate.id), [_x.id, _y.id],
        reason: 'X et Y v.1-2 tiennent sur la page 50 : une seule entrée');

    final pos = reanchorCursor(oldCycle, 1, newCycle);

    expect(pos, 1);
    expect(newCycle[pos!].map((u) => u.sourate.id), [_x.id]);
    expect(newCycle[2].single.sourate.id, _y.id);
    expect(newCycle[2].single.verseEnd, 2,
        reason: 'Y v.1-2, déjà dans l\'entrée partagée, a sa propre entrée '
            'après le curseur : il sera reproposé (E2)');
  });
}
