import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../widgets/verse_chip.dart';
import '../widgets/verse_chips_scaffold.dart';

/// Détail d'une sourate/portion du plan du jour, ouvert depuis
/// [CheckInScreen] — liste ses versets et permet de l'étendre d'un verset.
class CheckInDetailScreen extends StatefulWidget {
  final RevisionUnit unit;
  // The check-in's draft owns the plan: the detail only reports the new range.
  final void Function(RevisionUnit from, RevisionUnit to) onExtend;
  const CheckInDetailScreen(
      {super.key, required this.unit, required this.onExtend});

  @override
  State<CheckInDetailScreen> createState() => _CheckInDetailScreenState();
}

class _CheckInDetailScreenState extends State<CheckInDetailScreen> {
  late RevisionUnit _unit;

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
  }

  void _extend() {
    final next = _unit.verseEnd + 1;
    if (next > _unit.sourate.verses) return;
    final extended =
        RevisionUnit.spanning(_unit.sourate, _unit.verseStart, next);
    widget.onExtend(_unit, extended);
    setState(() => _unit = extended);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return VerseChipsScaffold(
      title: '${_unit.sourate.nameFr} · ${S.blocRange(_unit.verseStart, _unit.verseEnd)}',
      headerLabel: SCheckIn.checkInVersetsInclus,
      chips: [
        for (int v = _unit.verseStart; v <= _unit.verseEnd; v++)
          VerseChip(
            borderColor: palette.cardBorder,
            child: Text('$v', style: AppText.caption.copyWith(color: palette.textMuted)),
          ),
        if (_unit.verseEnd < _unit.sourate.verses)
          VerseChip(
            borderColor: palette.gold.withValues(alpha: 0.7),
            onTap: _extend,
            child: Icon(Icons.add, size: 14, color: palette.textPrimary),
          ),
      ],
      footer: Text(SCheckIn.checkInExtendHint,
          style: AppText.caption.copyWith(color: palette.textMuted)),
    );
  }
}
