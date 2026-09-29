import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/widgets/verse_range_slider.dart';

void main() {
  const range = RangeValues(10, 20);

  RangeValues nudge(RangeValues v, {required bool start, required int delta}) =>
      nudgeRange(v, start: start, delta: delta, min: 5, max: 25);

  test('±1 moves only the targeted bound', () {
    expect(nudge(range, start: true, delta: -1), const RangeValues(9, 20));
    expect(nudge(range, start: true, delta: 1), const RangeValues(11, 20));
    expect(nudge(range, start: false, delta: -1), const RangeValues(10, 19));
    expect(nudge(range, start: false, delta: 1), const RangeValues(10, 21));
  });

  test('bounds stay within min..max', () {
    expect(nudge(const RangeValues(5, 20), start: true, delta: -1), const RangeValues(5, 20));
    expect(nudge(const RangeValues(10, 25), start: false, delta: 1), const RangeValues(10, 25));
  });

  test('end never precedes start', () {
    const single = RangeValues(12, 12);
    expect(nudge(single, start: true, delta: 1), single);
    expect(nudge(single, start: false, delta: -1), single);
  });
}
