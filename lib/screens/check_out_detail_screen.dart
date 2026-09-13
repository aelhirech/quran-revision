import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../state/app_state.dart';
import '../widgets/verse_chip.dart';
import '../widgets/verse_chips_scaffold.dart';

/// Détail d'une sourate/portion du check-out — flague les versets « à
/// retravailler » un par un. Ouvert depuis [CheckOutScreen].
class CheckOutDetailScreen extends StatefulWidget {
  final String date;
  final RevisionUnit unit;
  final Set<int> initialNeedsWork;

  const CheckOutDetailScreen({
    super.key,
    required this.date,
    required this.unit,
    required this.initialNeedsWork,
  });

  @override
  State<CheckOutDetailScreen> createState() => _CheckOutDetailScreenState();
}

class _CheckOutDetailScreenState extends State<CheckOutDetailScreen> {
  late Set<int> _needsWork;

  @override
  void initState() {
    super.initState();
    _needsWork = {...widget.initialNeedsWork};
  }

  Future<void> _toggle(int verse) async {
    final flagged = !_needsWork.contains(verse);
    await context.read<AppState>().setVerseNeedsWork(
      widget.date,
      widget.unit.sourate.id,
      verse,
      flagged,
    );
    if (!mounted) return;
    setState(() {
      flagged ? _needsWork.add(verse) : _needsWork.remove(verse);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final unit = widget.unit;
    return VerseChipsScaffold(
      title: '${unit.sourate.nameFr} · v.${unit.verseStart}–${unit.verseEnd}',
      headerLabel: S.checkOutARetravailler,
      chips: [
        for (int v = unit.verseStart; v <= unit.verseEnd; v++)
          VerseChip(
            onTap: () => _toggle(v),
            borderColor: _needsWork.contains(v)
                ? palette.gold
                : palette.cardBorder,
            fillColor: _needsWork.contains(v) ? palette.gold : null,
            child: _needsWork.contains(v)
                ? Icon(Icons.bookmark, size: 14, color: palette.onPrimary)
                : Text(
                    '$v',
                    style: TextStyle(fontSize: 11, color: palette.textMuted),
                  ),
          ),
      ],
    );
  }
}
