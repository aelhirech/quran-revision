import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/revision_unit.dart';
import '../services/verse_service.dart';

class VerseBottomSheet extends StatelessWidget {
  final RevisionUnit unit;
  final int rakaaNumber;

  const VerseBottomSheet({
    super.key,
    required this.unit,
    required this.rakaaNumber,
  });

  static void show(BuildContext context, RevisionUnit unit, int rakaaNumber) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VerseBottomSheet(unit: unit, rakaaNumber: rakaaNumber),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final verses = VerseService.versesForUnit(unit);
    final surahId = unit.sourate.id;
    final surahNameAr = quran.getSurahNameArabic(surahId);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _handle(),
            _header(cs, surahNameAr),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: verses.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (_, i) => _verseRow(
                  cs,
                  verseNumber: unit.verseStart + i,
                  text: verses[i],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _handle() => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 4),
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _header(ColorScheme cs, String surahNameAr) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Text(
            surahNameAr,
            style: const TextStyle(
              fontSize: 28,
              fontFamily: 'Scheherazade',
              height: 1.8,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 4),
          Text(
            '${unit.sourate.nameFr}  ·  ${S.versetsDeRakaa}  (${unit.verseStart}–${unit.verseEnd})',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Divider(color: AppColors.cardBorder),
        ],
      ),
    );
  }

  Widget _verseRow(ColorScheme cs, {required int verseNumber, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(top: 4, left: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.greenContainer,
          ),
          child: Center(
            child: Text(
              '$verseNumber',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.green,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 22,
              height: 2.0,
              fontFamily: 'Scheherazade',
            ),
          ),
        ),
      ],
    );
  }
}
