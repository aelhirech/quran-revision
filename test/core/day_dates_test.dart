import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/day_dates.dart';

void main() {
  test('daysAgo compte des jours entiers, quelle que soit l\'heure', () {
    final lateEvening = DateTime(2026, 10, 1, 23, 59);
    expect(daysAgo('2026-10-01', now: lateEvening), 0);
    expect(daysAgo('2026-09-30', now: DateTime(2026, 10, 1, 0, 1)), 1);
    expect(daysAgo('2026-09-27', now: lateEvening), 4);
  });

  test('daysAgo ne glisse pas au changement d\'heure (journée de 23 h)', () {
    // Europe: clocks go forward on the night of 2026-03-29.
    expect(daysAgo('2026-03-29', now: DateTime(2026, 3, 30, 0, 30)), 1);
  });
}
