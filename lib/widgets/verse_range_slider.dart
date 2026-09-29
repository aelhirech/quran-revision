import 'package:flutter/material.dart';
import '../core/strings.dart';

/// Moves one bound of [values] by [delta] verses, clamped to [min]..[max] and
/// never crossing the other bound. Returns the rounded range.
RangeValues nudgeRange(RangeValues values,
    {required bool start, required int delta, required int min, required int max}) {
  final lo = values.start.round();
  final hi = values.end.round();
  return start
      ? RangeValues((lo + delta).clamp(min, hi).toDouble(), hi.toDouble())
      : RangeValues(lo.toDouble(), (hi + delta).clamp(lo, max).toDouble());
}

/// Verse range slider with a ±1 on each bound: the slider is for coarse moves
/// on long surahs (Al-Baqara, 286 verses), the ±1 gets to the exact verse.
/// Requires [max] > [min] (RangeSlider needs at least one division).
class VerseRangeSlider extends StatelessWidget {
  final int min;
  final int max;
  final RangeValues values;
  final ValueChanged<RangeValues> onChanged;

  /// Fired on slider release and on every ±1 — listeners doing costly work
  /// (restarting an audio loop) hook here, not on [onChanged].
  final ValueChanged<RangeValues>? onChangeEnd;

  const VerseRangeSlider({
    super.key,
    required this.min,
    required this.max,
    required this.values,
    required this.onChanged,
    this.onChangeEnd,
  });

  void _nudge({required bool start, required int delta}) {
    final next = nudgeRange(values, start: start, delta: delta, min: min, max: max);
    if (next == values) return;
    onChanged(next);
    onChangeEnd?.call(next);
  }

  Widget _step(IconData icon, String tooltip, {required bool start, required int delta}) =>
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(icon, size: 18),
        tooltip: tooltip,
        onPressed: () => _nudge(start: start, delta: delta),
      );

  Widget _bound(ColorScheme cs, {required bool start}) {
    final value = (start ? values.start : values.end).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _step(Icons.remove, start ? S.debutMoinsUn : S.finMoinsUn, start: start, delta: -1),
        Text('v.$value', style: TextStyle(fontWeight: FontWeight.w700, color: cs.primary)),
        _step(Icons.add, start ? S.debutPlusUn : S.finPlusUn, start: start, delta: 1),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = values.end.round() - values.start.round() + 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _bound(cs, start: true),
            Text('$count ${S.versetsLabel}', style: const TextStyle(fontWeight: FontWeight.w500)),
            _bound(cs, start: false),
          ],
        ),
        RangeSlider(
          values: values,
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: cs.primary,
          onChanged: onChanged,
          onChangeEnd: onChangeEnd,
        ),
      ],
    );
  }
}
