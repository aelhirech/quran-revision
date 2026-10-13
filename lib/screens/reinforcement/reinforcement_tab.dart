import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/reinforcement_engine.dart';
import '../../core/strings.dart';
import '../../models/sourate.dart';
import '../../services/verse_service.dart';
import '../../services/word_gloss_service.dart';
import '../../state/app_state.dart';
import '../../widgets/outlined_action_button.dart';
import '../../widgets/primary_cta_button.dart';
import '../../widgets/sourate_picker_sheet.dart';
import 'series_screen.dart';

enum SeriesMode { mix, passages, words }

class ReinforcementTab extends StatefulWidget {
  const ReinforcementTab({super.key});

  @override
  State<ReinforcementTab> createState() => _ReinforcementTabState();
}

class _ReinforcementTabState extends State<ReinforcementTab> {
  // Session memory only (US-20 crit. 1): the next series asks other passages
  // while the selection has some left.
  Set<(int, int, int)> _lastPrompts = {};
  // Kept apart from the passages: a word's rank and a passage's rank do not
  // name the same thing.
  Set<(int, int, int)> _lastWords = {};
  SeriesMode _mode = SeriesMode.mix;
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
    final mode = _withWords(state) ? _mode : SeriesMode.passages;
    final inputs = await state.reinforcementInputs();
    if (!mounted) return;
    if (mode != SeriesMode.passages) {
      await WordGlossService.load();
      if (!mounted) return;
    }
    String textOf(int surahId, int ayahId) =>
        VerseService.getVerse(surahId, ayahId, riwaya: state.riwaya);
    final random = Random();
    final List<SeriesQuestion> questions = switch (mode) {
      SeriesMode.passages => ReinforcementEngine.buildSeries(
          carried: inputs.carried,
          today: inputs.today,
          textOf: textOf,
          random: random,
          avoid: _lastPrompts,
          surahId: sourate?.id,
        ),
      SeriesMode.words => ReinforcementWords.buildWordQuestions(
          carried: inputs.carried,
          today: inputs.today,
          textOf: textOf,
          glossesOf: WordGlossService.glosses,
          random: random,
          avoid: _lastWords,
          surahId: sourate?.id,
        ),
      SeriesMode.mix => ReinforcementWords.buildMixedSeries(
          carried: inputs.carried,
          today: inputs.today,
          textOf: textOf,
          glossesOf: WordGlossService.glosses,
          random: random,
          avoidPassages: _lastPrompts,
          avoidWords: _lastWords,
          surahId: sourate?.id,
        ),
    };
    if (questions.isEmpty) {
      setState(() => _tooSmall = true);
      return;
    }
    final prompts = {
      for (final question in questions.whereType<PassageQuestion>())
        question.prompt.id,
    };
    final words = {
      for (final question in questions.whereType<WordQuestion>())
        question.answer.id,
    };
    setState(() {
      _tooSmall = false;
      // A series of one kind leaves the memory of the other kind as it was.
      if (prompts.isNotEmpty) _lastPrompts = prompts;
      if (words.isNotEmpty) _lastWords = words;
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

  bool _withWords(AppState state) =>
      WordGlossService.availableFor(S.locale, state.riwaya);

  Widget _modePicker() {
    // Enlarged text shrinks to fit rather than breaking inside a word.
    ButtonSegment<SeriesMode> segment(SeriesMode mode, String label) =>
        ButtonSegment(
          value: mode,
          label: FittedBox(
              fit: BoxFit.scaleDown, child: Text(label, maxLines: 1)),
        );
    return SegmentedButton<SeriesMode>(
      showSelectedIcon: false,
      // A 320 px screen leaves 85 px per segment: with the default padding
      // "Traduction" broke in two.
      style: SegmentedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 6)),
      segments: [
        segment(SeriesMode.mix, SReinforcement.modeMelange),
        segment(SeriesMode.passages, SReinforcement.modeVersets),
        segment(SeriesMode.words, SReinforcement.modeTraduction),
      ],
      selected: {_mode},
      onSelectionChanged: (picked) => setState(() {
        _mode = picked.single;
        _tooSmall = false;
      }),
    );
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
                        if (_withWords(state)) ...[
                          const SizedBox(height: 14),
                          _modePicker(),
                        ],
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
