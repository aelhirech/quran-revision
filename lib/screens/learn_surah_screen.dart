import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart' as quran;
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/sourate.dart';
import '../services/learning_service.dart';
import '../services/student_service.dart';
import '../widgets/dome_progress_card.dart';
import '../widgets/index_badge.dart';
import '../widgets/primary_cta_button.dart';
import '../widgets/verse_display_card.dart';

class LearnSurahScreen extends StatefulWidget {
  final LearningProgress progress;
  final VoidCallback onChanged;
  /// null = profil principal, sinon id du profil élève
  final String? studentId;

  const LearnSurahScreen({
    super.key,
    required this.progress,
    required this.onChanged,
    this.studentId,
  });

  @override
  State<LearnSurahScreen> createState() => _LearnSurahScreenState();
}

class _LearnSurahScreenState extends State<LearnSurahScreen> {
  late LearningProgress _progress;
  bool _verseVisible = false;
  int _selectedBlockSize = 1;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress;
  }

  int get _currentVerse => _progress.nextVerse;

  // N prochains versets non appris, capés à _selectedBlockSize.
  List<int> get _currentBlock {
    final result = <int>[];
    for (int v = 1;
        v <= _progress.sourate.verses && result.length < _selectedBlockSize;
        v++) {
      if (!_progress.learnedVerses.contains(v)) result.add(v);
    }
    return result;
  }

  Future<void> _markBlockLearned() async {
    HapticFeedback.mediumImpact();
    var updated = _progress;
    for (final v in _currentBlock) {
      updated = updated.withVerseLearned(v);
    }
    await _save(updated);
    if (!mounted) return;
    setState(() {
      _progress = updated;
      _verseVisible = false;
    });
    widget.onChanged();
    if (updated.isComplete && mounted) {
      _showCompletedDialog();
    }
  }

  Future<void> _save(LearningProgress updated) async {
    if (widget.studentId == null) {
      await LearningService.upsert(updated);
    } else {
      await StudentService.upsertProgress(widget.studentId!, updated);
    }
  }

  Future<void> _unmarkVerse(int verse) async {
    final updated = _progress.withVerseUnlearned(verse);
    await _save(updated);
    if (!mounted) return;
    setState(() => _progress = updated);
    widget.onChanged();
  }

  void _showCompletedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.sourateCompleted),
        content: Text(S.ajouterDesc),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.annuler),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, 'add_to_revision');
            },
            child: Text(S.ajouterAlaRevision),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = _progress.sourate;
    final block = _currentBlock;
    final blockVerseText = block
        .map((v) => quran.getVerse(s.id, v, verseEndSymbol: true))
        .join('\n\n');

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(s.nameFr),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _progressHeader(cs, s, block),
                const SizedBox(height: 16),
                if (!_progress.isComplete) _blockSizeSelector(cs),
                const SizedBox(height: 16),
                VerseDisplayCard(
                  verseText: blockVerseText,
                  visible: _verseVisible,
                  isComplete: _progress.isComplete,
                  onToggle: () => setState(() => _verseVisible = !_verseVisible),
                  blockSize: block.length,
                ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06),
                const SizedBox(height: 20),
                if (_progress.isComplete) _addToRevisionButton(cs) else _actionRow(cs, block.length),
                const SizedBox(height: 32),
                if (_progress.learnedCount > 0) _learnedList(cs, s),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _blockSizeSelector(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.versetsParBloc,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1')),
            ButtonSegment(value: 3, label: Text('3')),
            ButtonSegment(value: 5, label: Text('5')),
          ],
          selected: {_selectedBlockSize},
          onSelectionChanged: (sel) => setState(() {
            _selectedBlockSize = sel.first;
            _verseVisible = false;
          }),
          showSelectedIcon: false,
          style: const ButtonStyle(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 50.ms);
  }

  Widget _progressHeader(ColorScheme cs, Sourate s, List<int> block) {
    final posLabel = _progress.isComplete
        ? '✓'
        : block.length > 1
            ? '${S.blocRange(block.first, block.last)} / ${s.verses}'
            : S.versetN(_currentVerse, s.verses);
    final palette = context.palette;
    final onPrimary = palette.onPrimary;
    return DomeProgressCard(
      topRadius: 120,
      bottomRadius: 12,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(s.nameAr,
              style: GoogleFonts.amiri(fontSize: 22, color: onPrimary)),
          const SizedBox(height: 6),
          Text(
            posLabel,
            style: TextStyle(
                color: onPrimary.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
                fontSize: 12),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: _progress.progress,
                minHeight: 3,
                backgroundColor: onPrimary.withValues(alpha: 0.18),
                color: palette.gold,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06);
  }

  Widget _addToRevisionButton(ColorScheme cs) {
    return PrimaryCtaButton(
      label: S.ajouterAlaRevision,
      icon: Icons.add,
      onPressed: () => Navigator.pop(context, 'add_to_revision'),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _actionRow(ColorScheme cs, int blockLength) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _verseVisible
                ? () => setState(() => _verseVisible = false)
                : () => setState(() => _verseVisible = true),
            icon: Icon(_verseVisible ? Icons.visibility_off : Icons.visibility),
            label: Text(_verseVisible ? S.masquerVerset : S.afficherVerset),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: PrimaryCtaButton(
            height: 48,
            label: S.marquerBlocAppris(blockLength),
            icon: Icons.check,
            onPressed: _markBlockLearned,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _learnedList(ColorScheme cs, Sourate s) {
    final learned = _progress.learnedVerses.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.versetsApprisLabel.toUpperCase(),
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
                letterSpacing: 2,
                color: context.palette.textMuted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: learned.map((v) {
            return GestureDetector(
              onLongPress: () => _unmarkVerse(v),
              child: IndexBadge(text: '$v', state: IndexBadgeState.done),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(S.longPressDesapprendre,
            style: TextStyle(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: context.palette.textMuted)),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }
}
