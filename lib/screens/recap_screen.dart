import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/mosaic.dart' show MosaicTile, atRiskOldestFirst;
import '../core/strings.dart';
import '../models/sourate.dart';
import '../state/app_state.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/freshness_badge.dart';
import '../widgets/guide_step.dart';
import '../widgets/mosaic.dart';
import '../widgets/mosaic_tile_sheet.dart';
import '../widgets/mosaic_tile_shape.dart';
import '../widgets/ornamental_divider.dart';

/// What holds and what risks being forgotten (US-23): the mosaic, surahs
/// being learned included (US-32), and the surahs at risk. Nothing else.
class RecapScreen extends StatefulWidget {
  /// The shell keeps every tab mounted: reloads wait until this one shows.
  final bool shown;

  const RecapScreen({super.key, this.shown = true});

  @override
  State<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends State<RecapScreen> {
  List<MosaicTile>? _tiles;
  // A newer load makes an older one's result stale.
  int _generation = 0;
  late final AppState _state;

  @override
  void initState() {
    super.initState();
    _state = context.read<AppState>()..addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(RecapScreen old) {
    super.didUpdateWidget(old);
    // Notifications seen while hidden are caught up on showing.
    if (widget.shown && !old.shown) _refresh();
  }

  @override
  void dispose() {
    _state.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (widget.shown) _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final tiles = await _state.mosaicTiles(withLearning: true);
    if (!mounted || generation != _generation) return;
    setState(() => _tiles = tiles);
  }

  Future<void> _openTile(MosaicTile tile) async {
    // A riwaya switch can drop the surah before the tiles reload.
    final sourate = _state.sourateById(tile.surahId);
    if (sourate == null) return;
    // No series from here: the Recap looks back, the Quiz tab plays. The
    // sheet is the only way to abandon a learning from here (US-32 crit. 2).
    await MosaicTileSheet.show(
      context,
      tile,
      sourate,
      onAbandon: tile.learning == null
          ? null
          : () => _deleteLearning(sourate),
    );
  }

  // Tracking only (US-12): verses are credited or withdrawn at check-out,
  // never from here.
  Future<void> _deleteLearning(Sourate sourate) async {
    final confirmed = await confirmDialog(
      context,
      title: S.supprimerApprentissage,
      message: S.supprimerApprentissageDe(sourate.nameFr),
      confirmLabel: S.supprimer,
      danger: true,
    );
    if (!mounted || !confirmed) return;
    await _state.abandonLearning(sourate.id);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tiles = _tiles;
    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(S.recapitulatif),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
          ),
          if (state.guideDone('checkout_done') && !state.guideDone('recap_seen'))
            SliverToBoxAdapter(
              child: GuideStep(
                icon: Icons.bar_chart_outlined,
                title: SGuide.guideRecapTitle,
                body: SGuide.guideRecapBody,
                actionLabel: SGuide.guideContinuer,
                onAction: () => state.markGuideDone('recap_seen'),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: OrnamentalDivider(),
                ),
                // Nothing until the first load: the empty sentence must not
                // flash before the tiles arrive.
                if (tiles != null) ..._sections(tiles),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _sections(List<MosaicTile> tiles) {
    final atRisk = atRiskOldestFirst(tiles);
    if (tiles.isEmpty) {
      return [
        Text(S.recapVide,
            style: AppText.body.copyWith(color: context.palette.textMuted)),
      ];
    }
    return [
      Mosaic(tiles: tiles, onTap: _openTile),
      const SizedBox(height: 24),
      if (atRisk.isNotEmpty) ...[
        _sectionTitle(SReinforcement.risqueOublier),
        Card(
          child: Column(
            children: [for (final tile in atRisk) _riskRow(tile)],
          ),
        ),
        const SizedBox(height: 24),
      ],
    ];
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text.toUpperCase(),
            style: AppText.sectionTitle
                .copyWith(color: context.palette.textMuted)),
      );

  Widget _riskRow(MosaicTile tile) {
    final palette = context.palette;
    final name = _state.sourateById(tile.surahId)?.nameFr ?? '';
    final lastRevision = freshnessDiscreetLabel(
        _state.freshnessFor(tile.surahId, tile.verseStart, tile.verseEnd));
    return InkWell(
      onTap: () => _openTile(tile),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const MosaicTileShape(level: 0, atRisk: true, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: AppText.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary)),
                  Text(lastRevision,
                      style: AppText.caption.copyWith(color: palette.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: palette.textMuted),
          ],
        ),
      ),
    );
  }
}
