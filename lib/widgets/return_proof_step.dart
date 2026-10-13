import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import 'guide_step.dart';

/// Return-proof banner (US-1 sprint C) — names one concrete returning verse
/// (surah, verse) since a vague "some verses came back" would not prove
/// anything; any others returning the same day are folded into a trailing
/// count instead of listed, to keep the banner a sentence, not a list.
class ReturnProofStep extends StatelessWidget {
  final Map<(int, int), int?> returning;
  final VoidCallback onDone;

  const ReturnProofStep({
    super.key,
    required this.returning,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final (surahId, verseNumber) = returning.keys.first;
    final surahName =
        context.watch<AppState>().sourateById(surahId)?.nameFr ?? '';
    return GuideStep(
      icon: Icons.replay_outlined,
      title: SGuide.guideReturnProofTitle,
      body: SGuide.guideReturnProofBody(surahName, verseNumber, returning.length - 1),
      actionLabel: SGuide.guideContinuer,
      onAction: onDone,
    );
  }
}
