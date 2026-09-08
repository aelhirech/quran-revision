import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../models/user_config.dart';
import 'preset_dropdown.dart';

/// Sélecteur de rythme « N page(s) / jour ». Les presets, le libellé et les
/// textes du dialog "Personnalisé…" sont les mêmes partout : l'onboarding et
/// les Réglages en tenaient deux copies, et l'une des deux a raté le passage
/// au pluriel (« 1 pages/jour »).
class PagesPerDayDropdown extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final Color? color;

  const PagesPerDayDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) => PresetDropdown(
        value: value,
        presets: pagesPerDayPresets,
        labelBuilder: S.pagesParJour,
        customDialogTitle: S.pagesCustomTitle,
        customSuffix: S.pagesSuffix,
        color: color,
        onChanged: onChanged,
      );
}
