import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/reinforcement_engine.dart';
import '../../core/strings.dart';
import '../../models/sourate.dart';
import '../../services/verse_service.dart';
import '../../state/app_state.dart';
import '../../widgets/outlined_action_button.dart';
import '../../widgets/primary_cta_button.dart';
import '../../widgets/sourate_picker_sheet.dart';
import 'series_screen.dart';

class ReinforcementTab extends StatefulWidget {
  const ReinforcementTab({super.key});

  @override
  State<ReinforcementTab> createState() => _ReinforcementTabState();
}

class _ReinforcementTabState extends State<ReinforcementTab> {
  // Session memory only (US-20 crit. 1): the next series asks other passages
  // while the selection has some left.
  Set<(int, int, int)> _lastPrompts = {};
  bool _tooSmall = false;
  bool _busy = false;

  // Composing a series blocks for a few hundred ms: a second tap in that
  // window would stack a second series (or a second sheet) on the first.
  Future<void> _once(Future<void> Function() action) async {
    if (_busy) return;
    _busy = true;
    try {
      await action();
    } finally {
      _busy = false;
    }
  }

  Future<void> _start({Sourate? sourate}) async {
    final state = context.read<AppState>();
    final inputs = await state.reinforcementInputs();
    if (!mounted) return;
    final questions = ReinforcementEngine.buildSeries(
      carried: inputs.carried,
      today: inputs.today,
      textOf: (surahId, ayahId) =>
          VerseService.getVerse(surahId, ayahId, riwaya: state.riwaya),
      random: Random(),
      avoid: _lastPrompts,
      surahId: sourate?.id,
    );
    if (questions.isEmpty) {
      setState(() => _tooSmall = true);
      return;
    }
    setState(() {
      _tooSmall = false;
      _lastPrompts = {for (final question in questions) question.prompt.id};
    });
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SeriesScreen(
        questions: questions,
        title: sourate == null
            ? SReinforcement.serieDuJour
            : SReinforcement.serieSur(sourate.nameFr),
      ),
    ));
  }

  Future<void> _pickSourate() async {
    final state = context.read<AppState>();
    final inputs = await state.reinforcementInputs();
    if (!mounted) return;
    final picked = await showModalBottomSheet<Sourate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SouratePickerSheet(
        sourates: state.sourates
            .where((sourate) => inputs.carried.containsKey(sourate.id))
            .toList(),
        title: SReinforcement.choisirSourate,
      ),
    );
    if (picked == null || !mounted) return;
    await _start(sourate: picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final palette = context.palette;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(SReinforcement.onglet),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(SReinforcement.serieDuJour,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        Text(SReinforcement.serieDuJourDesc,
                            style: TextStyle(
                                fontSize: 14, color: palette.textMuted)),
                        const SizedBox(height: 16),
                        PrimaryCtaButton(
                            label: SReinforcement.commencer,
                            onPressed: () => _once(_start)),
                        if (_tooSmall) ...[
                          const SizedBox(height: 12),
                          Text(SReinforcement.selectionTropPetite,
                              style: TextStyle(
                                  fontSize: 13, color: palette.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedActionButton(
                  icon: Icons.menu_book_outlined,
                  label: SReinforcement.choisirSourate,
                  onTap: () => _once(_pickSourate),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
