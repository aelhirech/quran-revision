part of '../onboarding_screen.dart';

/// Segment de la liste des sourates : `header` non-null = groupe Hizb
/// (rendu en en-tête épinglé), `header == null` = liste plate (recherche
/// active ou groupement désactivé).
class _Section {
  final int? header;
  final List<Sourate> entries;
  const _Section(this.header, this.entries);
}

List<_Section> _sectionize(List<Object> items) {
  final sections = <_Section>[];
  int? currentHeader;
  var currentEntries = <Sourate>[];
  void flush() {
    if (currentHeader != null || currentEntries.isNotEmpty) {
      sections.add(_Section(currentHeader, currentEntries));
    }
  }

  for (final item in items) {
    if (item is int) {
      flush();
      currentHeader = item;
      currentEntries = <Sourate>[];
    } else {
      currentEntries.add(item as Sourate);
    }
  }
  flush();
  return sections;
}

class _SourateList extends StatelessWidget {
  final List<Object> items;
  final Map<int, SourateSelection> selections;
  final void Function(Sourate) onToggle;
  final Future<void> Function(Sourate) onLongPress;

  const _SourateList({
    required this.items,
    required this.selections,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final sections = _sectionize(items);
    return CustomScrollView(
      slivers: [
        for (final section in sections) ...[
          if (section.header != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _HizbHeaderDelegate(
                label: S.hizb(section.header!),
                palette: palette,
              ),
            ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _tile(palette, section.entries[i]),
              childCount: section.entries.length,
            ),
          ),
        ],
      ],
    );
  }

  Widget _tile(AppPalette palette, Sourate s) {
    final sel = selections[s.id];
    final selected = sel != null;
    return GestureDetector(
      onLongPress: () => onLongPress(s),
      child: CheckboxListTile(
        value: selected,
        onChanged: (_) {
          HapticFeedback.selectionClick();
          onToggle(s);
        },
        dense: true,
        title: Row(
          children: [
            Text(s.nameFr,
                style: TextStyle(fontSize: 14, color: palette.textPrimary)),
            if (sel != null && !sel.isWhole) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: palette.gold.withValues(alpha: 0.6)),
                ),
                child: Text('v.${sel.verseStart}–${sel.verseEnd}',
                    style: TextStyle(fontSize: 10, color: palette.goldDark)),
              ),
            ],
          ],
        ),
        subtitle: Text(
            '${sel != null && !sel.isWhole ? '${sel.verseCount}/${s.verses}' : s.verses} ${S.versetsLabel}',
            style: TextStyle(fontSize: 12, color: palette.textMuted)),
        secondary: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: IndexBadge(
                text: '${s.id}',
                size: 30,
                state: selected ? IndexBadgeState.selected : IndexBadgeState.unselected,
              ),
            ),
            const SizedBox(width: 10),
            Text(s.nameAr, style: GoogleFonts.amiri(fontSize: 18, color: palette.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _HizbHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String label;
  final AppPalette palette;

  const _HizbHeaderDelegate({required this.label, required this.palette});

  @override
  double get minExtent => 28;
  @override
  double get maxExtent => 28;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Color.alphaBlend(palette.gold.withValues(alpha: 0.14), palette.cream),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      // FittedBox : l'en-tête épinglé a une hauteur fixe (minExtent/maxExtent
      // ci-dessus) — sans ça, un réglage d'accessibilité "texte agrandi"
      // ferait déborder le label hors de sa bande.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: palette.goldDark,
                letterSpacing: 0.8)),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _HizbHeaderDelegate oldDelegate) =>
      label != oldDelegate.label || palette != oldDelegate.palette;
}
