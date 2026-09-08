import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';

/// Dialogue « es-tu sûr ? » partagé — titre, message, un bouton d'annulation
/// et un bouton de confirmation. Retourne `true` seulement si l'utilisateur a
/// confirmé (fermer par le voile ou le retour arrière vaut « non »).
///
/// Extrait en Phase 9 Sprint 2 : quatre écrans réécrivaient le même
/// `showDialog<bool>` + `AlertDialog`, et les copies avaient déjà divergé
/// (`pop()` vs `pop(false)`, `TextButton` vs `FilledButton` pour confirmer)
/// sans qu'aucune décision de design ne le justifie. [danger] est la seule
/// variante retenue, pour les actions destructrices.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(S.annuler),
        ),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: ctx.palette.danger,
                  foregroundColor: ctx.palette.onPrimary)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}
