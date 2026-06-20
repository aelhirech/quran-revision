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

class LearnSurahScreen extends StatefulWidget {
  final LearningProgress progress;
  final VoidCallback onChanged;

  const LearnSurahScreen({
    super.key,
    required this.progress,
    required this.onChanged,
  });

  @override
  State<LearnSurahScreen> createState() => _LearnSurahScreenState();
}

class _LearnSurahScreenState extends State<LearnSurahScreen> {
  late LearningProgress _progress;
  bool _verseVisible = false;

  @override
  void initState() {
    super.initState();
    _progress = widget.progress;
  }

  int get _currentVerse => _progress.nextVerse;

  Future<void> _markLearned() async {
    HapticFeedback.mediumImpact();
    final updated = _progress.withVerseLearned(_currentVerse);
    await LearningService.upsert(updated);
    setState(() {
      _progress = updated;
      _verseVisible = false;
    });
    widget.onChanged();

    if (updated.isComplete && mounted) {
      _showCompletedDialog();
    }
  }

  Future<void> _unmarkVerse(int verse) async {
    final updated = _progress.withVerseUnlearned(verse);
    await LearningService.upsert(updated);
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
    final verseText = quran.getVerse(s.id, _currentVerse, verseEndSymbol: true);

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
                _progressHeader(cs, s),
                const SizedBox(height: 24),
                _verseCard(cs, verseText),
                const SizedBox(height: 20),
                if (!_progress.isComplete) _actionRow(cs),
                const SizedBox(height: 32),
                if (_progress.learnedCount > 0) _learnedList(cs, s),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressHeader(ColorScheme cs, Sourate s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.green, AppColors.greenLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.green.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(s.nameAr,
                  style: GoogleFonts.scheherazadeNew(
                      fontSize: 22, color: Colors.white)),
              Text(
                _progress.isComplete ? '✓' : S.versetN(_currentVerse, s.verses),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: _progress.progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.versetsAppris(_progress.learnedCount, s.verses),
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06);
  }

  Widget _verseCard(ColorScheme cs, String verseText) {
    if (_progress.isComplete) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.greenContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(S.sourateCompleted,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.green)),
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _verseVisible = !_verseVisible),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _verseVisible ? Colors.white : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _verseVisible ? AppColors.green.withValues(alpha: 0.3) : Colors.transparent,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _verseVisible
            ? Column(
                children: [
                  Text(
                    verseText,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.scheherazadeNew(
                        fontSize: 28, height: 2.0, color: cs.onSurface),
                  ),
                  const SizedBox(height: 16),
                  Text(S.masquerVerset,
                      style: TextStyle(
                          color: cs.onSurfaceVariant, fontSize: 12)),
                ],
              )
            : Column(
                children: [
                  Icon(Icons.visibility_outlined,
                      color: cs.onSurfaceVariant, size: 32),
                  const SizedBox(height: 12),
                  Text(S.afficherVerset,
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Appuie pour révéler le verset',
                      style: TextStyle(
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          fontSize: 12)),
                ],
              ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06);
  }

  Widget _actionRow(ColorScheme cs) {
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
          child: FilledButton.icon(
            onPressed: _markLearned,
            icon: const Icon(Icons.check),
            label: Text(S.marquerAppris),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
            ),
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
        Text('Versets appris',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: cs.onSurface)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: learned.map((v) {
            return GestureDetector(
              onLongPress: () => _unmarkVerse(v),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.greenContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('$v',
                    style: const TextStyle(
                        color: AppColors.green, fontWeight: FontWeight.w700)),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text('Maintiens un verset pour le désapprendre',
            style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }
}
