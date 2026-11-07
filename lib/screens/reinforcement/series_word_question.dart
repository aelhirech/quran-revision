part of 'series_screen.dart';

extension _WordQuestionView on _SeriesScreenState {
  Widget _passageWithWord(AppPalette palette, WordQuestion question,
      {double fontSize = 24}) {
    final passage = question.passage;
    final shown = _shown([passage]);
    // Gold says nothing to a screen reader: the asked word is named instead.
    return Semantics(
      container: true,
      label: '$shown, ${SReinforcement.motDemande(question.answer.arabic)}',
      child: ExcludeSemantics(
        child: ArabicVerseText(
          text: shown,
          fontSize: fontSize,
          // The leading "…" is one more word in the text that is shown.
          highlightWord: question.wordIndex + (_leads(passage) ? 1 : 0),
          highlightColor: palette.gold,
        ),
      ),
    );
  }

  Widget _wordQuestion(AppPalette palette, WordQuestion question) {
    final answer = question.answer;
    final surah = _sourate(answer.surahId);
    const asked = TextStyle(fontSize: 16, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (question.arabicToMeaning) ...[
          Text(SReinforcement.sourateVerset(surah.nameFr, answer.ayahId),
              style: TextStyle(fontSize: 13, color: palette.textMuted)),
          const SizedBox(height: 8),
          _promptCard(_passageWithWord(palette, question)),
          const SizedBox(height: 18),
          Text(SReinforcement.queVeutDire, style: asked),
        ] else ...[
          const SizedBox(height: 8),
          Text(answer.gloss, style: const TextStyle(fontSize: 20, height: 1.4)),
          const SizedBox(height: 18),
          Text(SReinforcement.quelMot, style: asked),
        ],
        const SizedBox(height: 10),
        for (final (index, choice) in question.choices.indexed)
          _choice(
            question,
            index,
            text: question.arabicToMeaning ? choice.gloss : choice.arabic,
            latin: question.arabicToMeaning,
            wrongNote: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: choice.arabic,
                    style: GoogleFonts.amiri(
                        fontSize: 15, color: palette.textMuted)),
                TextSpan(text: SReinforcement.motSensSep),
                TextSpan(text: choice.gloss),
              ]),
              style: TextStyle(fontSize: 12, color: palette.textMuted),
            ),
          ),
        if (_picked != null) _wordFollowUp(palette, question, surah),
      ],
    );
  }

  Widget _wordFollowUp(
      AppPalette palette, WordQuestion question, Sourate surah) {
    final answer = question.answer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Asked from its meaning, the word was shown with no surah or
            // verse: they come with the answer.
            if (!question.arabicToMeaning) ...[
              const SizedBox(height: 8),
              Text(SReinforcement.sourateVerset(surah.nameFr, answer.ayahId),
                  style: TextStyle(fontSize: 13, color: palette.textMuted)),
            ],
            _passageWithWord(palette, question, fontSize: 20),
            const SizedBox(height: 4),
            Text(answer.gloss,
                style: const TextStyle(fontSize: 15, height: 1.4)),
            const SizedBox(height: 8),
            Text(SReinforcement.sourceMots,
                style: TextStyle(fontSize: 12, color: palette.textMuted)),
            _seeText(surah, answer.ayahId, answer.ayahId),
          ],
        ),
      ),
    );
  }
}
