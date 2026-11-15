import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/mosaic.dart' show MosaicTile;
import '../core/strings.dart';
import '../models/sourate.dart';
import '../state/app_state.dart';
import 'draggable_handle.dart';
import 'freshness_badge.dart';
import 'mosaic_tile_shape.dart';
import 'outlined_action_button.dart';
import 'primary_cta_button.dart';
import 'verse_bottom_sheet.dart';

/// What a tile holds: name, level, last revision, verses learned, and the
/// way to its text, to a series on it or to abandoning its learning (US-21
/// crit. 6, US-32 crit. 2).
class MosaicTileSheet extends StatelessWidget {
  final MosaicTile tile;
  final Sourate sourate;
  final String lastRevision;
  final VoidCallback onSeeText;
  final VoidCallback? onStartSeries;
  final VoidCallback? onAbandon;

  const MosaicTileSheet({
    super.key,
    required this.tile,
    required this.sourate,
    required this.lastRevision,
    required this.onSeeText,
    this.onStartSeries,
    this.onAbandon,
  });

  /// [onStartSeries] and [onAbandon] are shown only when given: a surah that
  /// offers no question gets no button that would lead nowhere.
  static Future<void> show(
    BuildContext context,
    MosaicTile tile,
    Sourate sourate, {
    VoidCallback? onStartSeries,
    VoidCallback? onAbandon,
  }) {
    final freshness = context.read<AppState>().freshnessFor(
      tile.surahId,
      tile.verseStart,
      tile.verseEnd,
    );
    // Each action closes the sheet first, then acts from the caller's context.
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => MosaicTileSheet(
        tile: tile,
        sourate: sourate,
        lastRevision: freshnessDiscreetLabel(freshness),
        onSeeText: () {
          Navigator.pop(sheetContext);
          VerseBottomSheet.show(
            context,
            sourate,
            tile.verseStart,
            tile.verseEnd,
          );
        },
        onStartSeries: onStartSeries == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                onStartSeries();
              },
        onAbandon: onAbandon == null
            ? null
            : () {
                Navigator.pop(sheetContext);
                onAbandon();
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final partial = tile.verseStart != 1 || tile.verseEnd != sourate.verses;
    final muted = AppText.caption.copyWith(color: palette.textMuted);
    final arabic = GoogleFonts.amiri(fontSize: 22, color: palette.textPrimary);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Center(child: DraggableHandle()),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: Text(sourate.nameFr, style: AppText.cardTitle)),
                const SizedBox(width: 12),
                Text(sourate.nameAr, style: arabic),
              ],
            ),
            if (partial) ...[
              const SizedBox(height: 2),
              Text(S.blocRange(tile.verseStart, tile.verseEnd), style: muted),
            ],
            if (tile.learning case final learning?) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  MosaicTileShape(
                    level: tile.level,
                    atRisk: false,
                    size: 28,
                    learningFraction: tile.learningFraction,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      S.versetsAppris(
                        learning.learnedCount,
                        learning.totalVerses,
                      ),
                      style: AppText.body,
                    ),
                  ),
                ],
              ),
            ],
            if (!tile.isLearningOnly) ..._revised(muted),
            if (onAbandon != null) ...[
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: onAbandon,
                icon: const Icon(Icons.delete_outline),
                label: Text(S.supprimerApprentissage),
                style: TextButton.styleFrom(foregroundColor: palette.danger),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // What the revised range holds: level, risk, last revision, text, series.
  List<Widget> _revised(TextStyle muted) => [
    const SizedBox(height: 16),
    Row(
      children: [
        // The level's own shape, even at risk: the tile's orange
        // star hides it, the sheet is where it is read.
        MosaicTileShape(level: tile.level, atRisk: false, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(SReinforcement.niveau(tile.level), style: AppText.body),
        ),
      ],
    ),
    if (tile.atRisk) ...[
      const SizedBox(height: 10),
      Row(
        children: [
          const MosaicTileShape(level: 0, atRisk: true, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(SReinforcement.risqueOublier, style: AppText.body),
          ),
        ],
      ),
    ],
    const SizedBox(height: 14),
    Text(SReinforcement.derniereRevision, style: muted),
    const SizedBox(height: 2),
    Text(lastRevision, style: AppText.body),
    const SizedBox(height: 20),
    if (onStartSeries != null) ...[
      PrimaryCtaButton(
        label: SReinforcement.lancerSerieSur,
        onPressed: onStartSeries,
      ),
      const SizedBox(height: 10),
    ],
    OutlinedActionButton(
      icon: Icons.menu_book_outlined,
      label: S.voirLeTexte,
      onTap: onSeeText,
    ),
  ];
}
