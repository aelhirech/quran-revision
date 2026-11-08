import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/app_theme.dart';
import '../../core/mosaic.dart' show MosaicTile;
import '../../core/reinforcement_engine.dart';
import '../../core/strings.dart';
import '../../models/riwaya.dart';
import '../../models/sourate.dart';
import '../../services/verse_service.dart';
import '../../services/word_gloss_service.dart';
import '../../state/app_state.dart';
import '../../widgets/mosaic.dart';
import '../../widgets/mosaic_tile_sheet.dart';
import '../../widgets/outlined_action_button.dart';
import '../../widgets/primary_cta_button.dart';
import '../../widgets/sourate_picker_sheet.dart';
import 'series_screen.dart';

part 'reinforcement_tab_offer.dart';
part 'reinforcement_tab_series.dart';

enum SeriesMode { mix, passages, words }

class ReinforcementTab extends StatefulWidget {
  /// The shell keeps every tab mounted: the offer, costly on a large
  /// selection, is worked out only while this one is on screen.
  final bool shown;

  const ReinforcementTab({super.key, this.shown = true});

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
  bool _busy = false;
  final _corpus = ReinforcementCorpus();
  Riwaya? _corpusRiwaya;
  late final AppState _state;

  // The surahs that offer a question in the current mode; null until known.
  Set<int>? _offered;
  ({SeriesMode mode, Riwaya riwaya, Map<int, Set<int>> carried})? _offeredFor;
  // A newer computation makes an older one's result stale.
  int _generation = 0;

  List<MosaicTile>? _tiles;
  int _tilesGeneration = 0;

  bool get _tooSmall => _offered?.isEmpty ?? false;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>()..addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(ReinforcementTab old) {
    super.didUpdateWidget(old);
    // Notifications seen while hidden are caught up on showing.
    if (widget.shown && !old.shown) _refresh();
  }

  @override
  void dispose() {
    _state.removeListener(_refresh);
    super.dispose();
  }

  SeriesMode _modeFor(AppState state) =>
      _withWords(state) ? _mode : SeriesMode.passages;

  // setState is protected: the part-file extensions cannot call it directly.
  void _update(VoidCallback change) => setState(change);

  void _refresh() {
    if (!widget.shown) return;
    _computeOffer();
    _loadTiles();
  }

  Future<void> _loadTiles() async {
    final generation = ++_tilesGeneration;
    final tiles = await _state.mosaicTiles();
    if (!mounted || generation != _tilesGeneration) return;
    setState(() => _tiles = tiles);
  }

  Future<void> _openTile(MosaicTile tile) async {
    // Unknown offer (mode just changed): the button would be hidden wrongly.
    if (_offered == null) await _computeOffer();
    // A riwaya switch can drop the surah before the tiles reload.
    final sourate = _state.sourateById(tile.surahId);
    if (!mounted || sourate == null) return;
    await MosaicTileSheet.show(context, tile, sourate,
        onStartSeries: (_offered?.contains(tile.surahId) ?? false)
            ? () => _once(() => _start(sourate: sourate))
            : null);
  }

  void _refreshOffer() {
    if (widget.shown) _computeOffer();
  }

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
    final mode = _modeFor(state);
    final (inputs, quiz) = await (
      state.reinforcementInputs(),
      state.reinforcementSeriesInputs()
    ).wait;
    if (!mounted) return;
    if (mode != SeriesMode.passages) {
      await WordGlossService.load();
      if (!mounted) return;
    }
    final riwaya = state.riwaya;
    String textOf(int surahId, int ayahId) =>
        VerseService.getVerse(surahId, ayahId, riwaya: riwaya);
    final corpus = _corpusFor(riwaya);
    // A tap during the offer's warm-up: finish it in slices rather than in
    // one block below. On a warm memo nothing is analysed again.
    await _warm(corpus, inputs.carried, mode, textOf);
    // Another riwaya meanwhile: the memo now holds its text, not this one's.
    if (!mounted || state.riwaya != riwaya) return;
    final random = Random();
    final questions = _composeSeries(
      mode: mode,
      carried: inputs.carried,
      today: inputs.today,
      textOf: textOf,
      random: random,
      avoidPassages: _lastPrompts,
      avoidWords: _lastWords,
      surahId: sourate?.id,
      corpus: corpus,
      quiz: quiz,
    );
    // Fallback only: the offer and the composers share their condition.
    if (questions.isEmpty) {
      final surahId = sourate?.id;
      setState(() => _offered = {
            if (surahId != null)
              for (final id in _offered ?? const <int>{})
                if (id != surahId) id,
          });
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
      // A series of one kind leaves the memory of the other kind as it was.
      if (prompts.isNotEmpty) _lastPrompts = prompts;
      if (words.isNotEmpty) _lastWords = words;
    });
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => SeriesScreen(
        questions: questions,
        levelsBefore: quiz.levels,
        title: sourate == null
            ? SReinforcement.serieDuJour
            : SReinforcement.serieSur(sourate.nameFr),
      ),
    ));
    // The answers just given may have moved a level.
    if (mounted) _loadTiles();
  }

  Future<void> _pickSourate() async {
    final state = context.read<AppState>();
    // Up to date on return, unless the selection changes meanwhile.
    await _computeOffer();
    if (!mounted) return;
    final offered = _offered ?? const {};
    final picked = await SouratePickerSheet.show(
      context,
      sourates: state.sourates
          .where((sourate) => offered.contains(sourate.id))
          .toList(),
      title: SReinforcement.choisirSourate,
    );
    if (picked == null || !mounted) return;
    await _start(sourate: picked);
  }

  bool _withWords(AppState state) =>
      WordGlossService.availableFor(S.locale, state.riwaya);

  Widget _modePicker() {
    // The whole control shrinks, so the three labels keep one shared size
    // instead of each segment shrinking on its own.
    ButtonSegment<SeriesMode> segment(SeriesMode mode, String label) =>
        ButtonSegment(value: mode, label: Text(label, maxLines: 1));
    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SegmentedButton<SeriesMode>(
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
          onSelectionChanged: (picked) {
            // The old mode's offer must not show while the new one is worked out.
            setState(() {
              _mode = picked.single;
              _offered = null;
            });
            _refreshOffer();
          },
        ),
      ),
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
                if (_tiles case final tiles? when tiles.isNotEmpty) ...[
                  Mosaic(tiles: tiles, onTap: _openTile),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(SReinforcement.serieDuJour,
                            style: AppText.cardTitle),
                        const SizedBox(height: 6),
                        Text(SReinforcement.serieDuJourDesc,
                            style: AppText.body
                                .copyWith(color: palette.textMuted)),
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
                              style: AppText.caption
                                  .copyWith(color: palette.textMuted)),
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
