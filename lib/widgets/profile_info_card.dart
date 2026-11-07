import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/app_theme.dart';
import '../core/strings.dart';
import '../models/user_config.dart';

/// Carte « mon parcours » des Réglages : ce qui définit la révision (rythme,
/// sourates sélectionnées) et ce qu'elle a produit (jours écoulés, sourates
/// mémorisées), dans une seule liste.
///
/// Depuis la Phase 9 Sprint 2, les deux premières lignes sont **éditables sur
/// place** : rythme et sourates étaient auparavant deux boutons posés dans
/// l'AppBar, à part du reste de la page, alors qu'ils décrivent exactement ce
/// que cette carte affiche déjà. Bâtie sur `ListTile` + `Divider(indent: 56)`
/// comme `SettingsCard` juste en dessous : deux styles de ligne de réglage
/// sur le même écran désaligneraient les séparateurs et les hauteurs.
class ProfileInfoCard extends StatelessWidget {
  final UserConfig config;
  final int elapsed;
  final VoidCallback onEditRythme;
  final VoidCallback onEditSourates;

  const ProfileInfoCard({
    super.key,
    required this.config,
    required this.elapsed,
    required this.onEditRythme,
    required this.onEditSourates,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _row(cs, Icons.auto_stories_outlined, S.rythmeLabelCourt,
              S.pagesParJour(config.pagesPerDay), 0, onTap: onEditRythme),
          const Divider(height: 1, indent: 56),
          _row(cs, Icons.playlist_add_check_outlined, SOnboarding.souratesAReviser,
              '${config.selections.length}', 60, onTap: onEditSourates),
          const Divider(height: 1, indent: 56),
          _row(cs, Icons.today_outlined, S.joursEcoules,
              S.joursDuration(elapsed), 120),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _row(ColorScheme cs, IconData icon, String label, String value,
      int delayMs,
      {VoidCallback? onTap}) {
    // A plain Row instead of ListTile's trailing: the trailing gets only a
    // sliver of width, so a long label squeezed the value into one letter
    // per line with large text.
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, color: cs.primary),
              const SizedBox(width: 16),
              Expanded(child: Text(label, style: AppText.body)),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    children: [
                      Text(value,
                          style: AppText.body.copyWith(
                              fontWeight: FontWeight.w700,
                              color: cs.onSurface)),
                      if (onTap != null)
                        Icon(Icons.chevron_right,
                            size: 20, color: cs.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs))
        .slideX(begin: 0.05);
  }
}
