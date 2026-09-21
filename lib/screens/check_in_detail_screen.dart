import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../state/app_state.dart';
import '../widgets/verse_chip.dart';
import '../widgets/verse_chips_scaffold.dart';

/// Détail d'une sourate/portion du plan du jour, ouvert depuis
/// [CheckInScreen] — liste ses versets et permet de l'étendre d'un verset.
class CheckInDetailScreen extends StatefulWidget {
  final RevisionUnit unit;
  const CheckInDetailScreen({super.key, required this.unit});

  @override
  State<CheckInDetailScreen> createState() => _CheckInDetailScreenState();
}

class _CheckInDetailScreenState extends State<CheckInDetailScreen> {
  late RevisionUnit _unit;
  bool _extending = false;

  @override
  void initState() {
    super.initState();
    _unit = widget.unit;
  }

  Future<void> _extend() async {
    if (_extending) return; // évite un double-tap qui étendrait de 2 versets
    final next = _unit.verseEnd + 1;
    if (next > _unit.sourate.verses) return;
    setState(() => _extending = true);
    await context.read<AppState>().extendDayPlanVerse(_unit.sourate.id, next);
    if (!mounted) return;
    setState(() {
      _extending = false;
      _unit = RevisionUnit(
          sourate: _unit.sourate,
          verseStart: _unit.verseStart,
          verseEnd: next,
          isWhole: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return VerseChipsScaffold(
      title: '${_unit.sourate.nameFr} · v.${_unit.verseStart}–${_unit.verseEnd}',
      headerLabel: SCheckIn.checkInVersetsInclus,
      chips: [
        for (int v = _unit.verseStart; v <= _unit.verseEnd; v++)
          VerseChip(
            borderColor: palette.cardBorder,
            child: Text('$v', style: TextStyle(fontSize: 11, color: palette.textMuted)),
          ),
        if (_unit.verseEnd < _unit.sourate.verses)
          VerseChip(
            borderColor: palette.gold.withValues(alpha: 0.7),
            onTap: _extend,
            child: Icon(Icons.add, size: 14, color: palette.textPrimary),
          ),
      ],
      footer: Text(SCheckIn.checkInExtendHint,
          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: palette.textMuted)),
    );
  }
}
