import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../state/app_state.dart';

/// Settings edit mode body; selection and search state stay in `ProfileScreen`.
class ProfileEditBody extends StatelessWidget {
  final int pagesPerDay;
  final Set<int> selectedIds;
  final String search;
  final VoidCallback onToggleAll;
  final ValueChanged<int> onToggleSourate;
  final ValueChanged<String> onSearchChanged;

  const ProfileEditBody({
    super.key,
    required this.pagesPerDay,
    required this.selectedIds,
    required this.search,
    required this.onToggleAll,
    required this.onToggleSourate,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sourates = context.watch<AppState>().sourates;
    final totalSourates = sourates.length;
    final filtered = sourates.where((s) => s.matchesSearch(search)).toList();
    return SliverFillRemaining(
      child: Column(
        children: [
          Container(
            color: cs.primaryContainer,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Non-interactif : le rythme s'édite depuis la ligne
                // « Rythme » de la carte parcours — deux façons d'éditer le
                // même réglage sur cette page créait une redondance non
                // harmonisée (retour TestFlight 2026-09-01).
                // One Text.rich so the two parts wrap together with large text.
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(color: cs.onPrimaryContainer),
                      children: [
                        TextSpan(text: S.reviserEn),
                        TextSpan(
                          text: S.pagesParJour(pagesPerDay),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: TextButton.icon(
                    onPressed: onToggleAll,
                    icon: Icon(
                      selectedIds.length == totalSourates
                          ? Icons.deselect
                          : Icons.select_all,
                      color: cs.onPrimaryContainer,
                      size: 16,
                    ),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        selectedIds.length == totalSourates
                            ? SOnboarding.toutDeselectionner
                            : SOnboarding.toutSelectionner,
                        style: AppText.caption.copyWith(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: S.rechercher,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: onSearchChanged,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final s = filtered[i];
                final selected = selectedIds.contains(s.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) => onToggleSourate(s.id),
                  title: Text(s.nameFr),
                  subtitle: Text(
                    // Isolate the Arabic name so the bidi algorithm doesn't pull the
                    // following number into the RTL run (shown as "286 · البقرة").
                    '\u2068${s.nameAr}\u2069  ·  ${s.verses} ${S.versetsLabel}',
                  ),
                  secondary: CircleAvatar(
                    backgroundColor: selected
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    foregroundColor: selected
                        ? cs.onPrimary
                        : cs.onSurfaceVariant,
                    radius: 18,
                    child: Text('${s.id}', style: AppText.caption),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
