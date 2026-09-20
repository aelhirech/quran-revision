import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'verse_chip.dart';

/// Une rangée de chips verset par verset, cochés par défaut — taper en
/// bascule un dans/hors de [unchecked]. Même geste partagé par le check-out
/// révision (`CheckOutRow`) et le volet apprentissage (`check_out_sections`,
/// `_learnSection`) : confirmer/corriger ce qui a été fait, verset par
/// verset (US-3 crit. 3) — seuls la couleur et le contenu du chip "coché"
/// varient entre les deux.
class VerseToggleChips extends StatelessWidget {
  final List<int> verses;
  final Set<int> unchecked;
  final void Function(int ayahId) onToggle;
  final Color checkedBorderColor;
  final Color? checkedFillColor;
  final Widget Function(int ayahId, bool checked) childFor;

  /// Chips supplémentaires ajoutés à la suite, dans le même `Wrap` (ex. le
  /// chip "+" pour déclarer un verset appris en plus).
  final List<Widget> trailing;

  const VerseToggleChips({
    super.key,
    required this.verses,
    required this.unchecked,
    required this.onToggle,
    required this.checkedBorderColor,
    this.checkedFillColor,
    required this.childFor,
    this.trailing = const [],
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in verses)
          VerseChip(
            onTap: () => onToggle(v),
            borderColor:
                unchecked.contains(v) ? palette.cardBorder : checkedBorderColor,
            fillColor: unchecked.contains(v) ? null : checkedFillColor,
            child: childFor(v, !unchecked.contains(v)),
          ),
        ...trailing,
      ],
    );
  }
}
