import 'package:flutter/material.dart';
import '../../../core/app_colors.dart';
import '../../../core/app_theme.dart';
import '../../../widgets/arabic_verse_text.dart';
import 'series_marks.dart';

enum ChoiceState { idle, correct, pickedWrong, dimmed }

/// One proposed passage of a question. [note] is the line shown under a wrong
/// pick.
class PassageChoice extends StatelessWidget {
  final String text;
  final ChoiceState state;
  final String? note;
  final VoidCallback? onTap;

  const PassageChoice({
    super.key,
    required this.text,
    required this.state,
    this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final note = this.note;
    final marked =
        state == ChoiceState.correct || state == ChoiceState.pickedWrong;
    final themeShape = cardShape(palette);
    final ShapeBorder? shape = switch (state) {
      ChoiceState.correct => themeShape.copyWith(
          side: BorderSide(color: palette.gold, width: 2)),
      ChoiceState.pickedWrong => themeShape.copyWith(
          side: BorderSide(color: palette.textMuted, width: 1.5)),
      ChoiceState.idle || ChoiceState.dimmed => null,
    };

    return Opacity(
      opacity: state == ChoiceState.dimmed ? 0.5 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            shape: shape,
            // The ripple is shaped here rather than by clipping the Card:
            // tall Quranic marks rise above their line and were cut off.
            child: InkWell(
              customBorder: themeShape,
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: [
                    if (marked) ...[
                      SeriesMarks(
                          held: [state == ChoiceState.correct], total: 1),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: ArabicVerseText(text: text, fontSize: 20)),
                  ],
                ),
              ),
            ),
          ),
          if (note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
              child: Text(note,
                  style: TextStyle(fontSize: 12, color: palette.textMuted)),
            ),
        ],
      ),
    );
  }
}
