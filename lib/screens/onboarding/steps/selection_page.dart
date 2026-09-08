part of '../onboarding_screen.dart';

class _SelectionPage extends StatelessWidget {
  final Map<int, SourateSelection> selections;
  final int totalVerses;
  final bool groupByHizb;
  final String search;
  final List<Object> listItems;
  final double? lastQuickFraction;
  final void Function(double fraction) onQuickSelect;
  final void Function(Sourate) onToggleSourate;
  final Future<void> Function(Sourate) onLongPress;
  final ValueChanged<bool> onGroupByHizbChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onNext;

  const _SelectionPage({
    required this.selections,
    required this.totalVerses,
    required this.groupByHizb,
    required this.search,
    required this.listItems,
    required this.lastQuickFraction,
    required this.onQuickSelect,
    required this.onToggleSourate,
    required this.onLongPress,
    required this.onGroupByHizbChanged,
    required this.onSearchChanged,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Column(
        children: [
          _StepHeader(
            step: 1,
            total: _kOnboardingSteps,
            title: S.etapeSelection,
            subtitle: S.souratesCount(selections.length, totalVerses),
          ),
          // Boutons de sélection rapide
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(S.selectionRapide,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PillChip(
                      label: S.toutLeCoran,
                      onTap: () => onQuickSelect(1.0),
                      selected: lastQuickFraction == 1.0,
                    ),
                    const SizedBox(width: 6),
                    PillChip(
                      label: S.fractionTroisQuarts,
                      onTap: () => onQuickSelect(0.75),
                      selected: lastQuickFraction == 0.75,
                    ),
                    const SizedBox(width: 6),
                    PillChip(
                      label: S.fractionMoitie,
                      onTap: () => onQuickSelect(0.5),
                      selected: lastQuickFraction == 0.5,
                    ),
                    const SizedBox(width: 6),
                    PillChip(
                      label: S.fractionQuart,
                      onTap: () => onQuickSelect(0.25),
                      selected: lastQuickFraction == 0.25,
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.08),
          // Recherche + groupement
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: S.rechercherSourate,
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      isDense: true,
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                _GroupToggle(
                  icon: Icons.menu_book_outlined,
                  label: S.hizbCourt,
                  value: groupByHizb,
                  onChanged: onGroupByHizbChanged,
                ),
              ],
            ),
          ),
          // Liste (sticky headers Hizb)
          Expanded(
            child: _SourateList(
              items: listItems,
              selections: selections,
              onToggle: onToggleSourate,
              onLongPress: onLongPress,
            ).animate().fadeIn(duration: 300.ms),
          ),
          // Bouton suivant
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onNext,
                child: Text(
                  onNext == null ? S.selectSourates : S.continuer,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
