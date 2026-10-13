import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/reinforcement_engine.dart';
import '../../core/strings.dart';
import '../../models/sourate.dart';
import '../../state/app_state.dart';
import '../../widgets/arabic_verse_text.dart';
import '../../widgets/primary_cta_button.dart';
import '../../widgets/step_footer.dart';
import '../../widgets/step_transition.dart';
import '../../widgets/verse_bottom_sheet.dart';
import '../../widgets/verse_row.dart';
import 'widgets/passage_choice.dart';
import 'widgets/series_marks.dart';

// "…" marks a passage cut inside its verse. A choice never takes the leading
// one: next to choices that start a verse, it would single out the answer.
String _shown(List<Passage> run, {bool lead = true}) {
  final before = lead && !run.first.startsVerse ? '… ' : '';
  final after = run.last.endsVerse ? '' : ' …';
  return '$before${run.map((passage) => passage.text).join(' ')}$after';
}

/// One series, from the first question to the score. Nothing is stored:
/// leaving it, at any point, only pops the route.
class SeriesScreen extends StatefulWidget {
  final List<SeriesQuestion> questions;
  final String title;

  const SeriesScreen({super.key, required this.questions, required this.title});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  int _index = 0;
  Passage? _picked;
  final List<bool> _held = [];

  int get _total => widget.questions.length;

  Sourate _sourate(int id) =>
      context.read<AppState>().sourates.firstWhere((surah) => surah.id == id);

  Widget _eyebrow(String text, AppPalette palette) => Text(text.toUpperCase(),
      style: GoogleFonts.lora(
          color: palette.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 2.5));

  void _pick(SeriesQuestion question, Passage choice) => setState(() {
        _picked = choice;
        _held.add(choice.id == question.answer.id);
      });

  void _next() => setState(() {
        _index++;
        _picked = null;
      });

  ChoiceState _stateOf(SeriesQuestion question, Passage choice) {
    final picked = _picked;
    if (picked == null) return ChoiceState.idle;
    if (choice.id == question.answer.id) return ChoiceState.correct;
    if (choice.id == picked.id) return ChoiceState.pickedWrong;
    return ChoiceState.dimmed;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final finished = _index == _total;
    return Scaffold(
      backgroundColor: palette.cream,
      body: SafeArea(
        child: Column(
          children: [
            _header(palette, finished),
            Expanded(
              child: StepTransition(
                step: _index,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: finished
                      ? _summary(palette)
                      : _question(palette, widget.questions[_index]),
                ),
              ),
            ),
            StepFooter(
              primary: finished
                  ? PrimaryCtaButton(
                      label: SReinforcement.fermer,
                      onPressed: () => Navigator.pop(context))
                  : PrimaryCtaButton(
                      label: SCheckIn.suivant,
                      onPressed: _picked == null ? null : _next),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(AppPalette palette, bool finished) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: SReinforcement.fermer,
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(child: _eyebrow(widget.title, palette)),
                if (!finished) ...[
                  const SizedBox(width: 8),
                  _eyebrow(
                      SReinforcement.progression(_index + 1, _total), palette),
                ],
              ],
            ),
          ),
          if (!finished)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: SeriesMarks(held: _held, total: _total, current: _index),
            ),
        ],
      );

  Widget _question(AppPalette palette, SeriesQuestion question) {
    final prompt = question.prompt;
    final surah = _sourate(prompt.surahId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(SReinforcement.sourateVerset(surah.nameFr, prompt.ayahId),
            style: TextStyle(fontSize: 13, color: palette.textMuted)),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: ArabicVerseText(text: _shown([prompt])),
          ),
        ),
        const SizedBox(height: 18),
        Text(SReinforcement.quelleSuite,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        for (final choice in question.choices) _choice(question, choice),
        if (_picked != null) _followUp(palette, question, surah),
      ],
    );
  }

  Widget _choice(SeriesQuestion question, Passage choice) {
    final state = _stateOf(question, choice);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: PassageChoice(
        text: _shown([choice], lead: false),
        state: state,
        note: state == ChoiceState.pickedWrong
            ? SReinforcement.passageDans(
                _sourate(choice.surahId).nameFr, choice.ayahId)
            : null,
        onTap: _picked == null ? () => _pick(question, choice) : null,
      ),
    );
  }

  Widget _followUp(AppPalette palette, SeriesQuestion question, Sourate surah) {
    final prompt = question.prompt;
    final answer = question.answer;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _eyebrow(SReinforcement.laSuite, palette),
            const SizedBox(height: 10),
            if (prompt.ayahId == answer.ayahId)
              VerseRow(
                  number: prompt.ayahId,
                  text: _shown([prompt, answer]),
                  fontSize: 20)
            else ...[
              VerseRow(
                  number: prompt.ayahId, text: _shown([prompt]), fontSize: 20),
              VerseRow(
                  number: answer.ayahId, text: _shown([answer]), fontSize: 20),
            ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.menu_book_outlined, size: 18),
                label: Text(S.voirLeTexte),
                onPressed: () => VerseBottomSheet.show(
                    context, surah, prompt.ayahId, answer.ayahId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summary(AppPalette palette) => Column(
        children: [
          const SizedBox(height: 32),
          Text(
              SReinforcement.progression(
                  _held.where((held) => held).length, _total),
              style: const TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w600, height: 1.1)),
          const SizedBox(height: 18),
          SeriesMarks(held: _held, total: _total),
          const SizedBox(height: 24),
          Text(SReinforcement.finSerieNote,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: palette.textMuted)),
        ],
      );
}
