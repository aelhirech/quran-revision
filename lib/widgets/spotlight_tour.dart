import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';

/// Clés stables des éléments pointés par le tour guidé — attachées via
/// [KeyedSubtree] aux widgets réels dans HomeScreen/ShellScreen, sans avoir
/// à faire remonter de GlobalKey à travers les constructeurs.
class TourKeys {
  /// Une clé par onglet plutôt qu'une seule pour toute la barre (Phase 9
  /// Sprint 2) : le tour surligne l'onglet dont il parle, et non les trois à
  /// la fois pendant trois étapes identiques.
  static final tabPlan = GlobalKey();
  static final tabRecap = GlobalKey();
  static final tabReglages = GlobalKey();
  static final voirPlanButton = GlobalKey();
}

class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String body;

  /// Marge du halo autour de la cible. Une icône d'onglet a besoin de plus
  /// d'air qu'un bouton pleine largeur pour rester confortablement tapable.
  final double padding;

  const TourStep({
    required this.targetKey,
    required this.title,
    required this.body,
    this.padding = 8,
  });
}

/// Tour guidé avec surbrillance : assombrit l'écran sauf autour du widget
/// ciblé par l'étape courante, avec une bulle d'explication et des contrôles
/// Suivant/Passer. Ne nécessite aucune dépendance externe — juste les
/// GlobalKeys déjà posées sur les widgets à mettre en avant.
///
/// **Le halo est traversant** (Phase 9 Sprint 2) : les taps qui tombent
/// dedans atteignent le vrai widget en dessous, ce qui laisse la dernière
/// étape ouvrir directement l'écran qu'elle présente. Tout ce qui tombe à
/// côté est en revanche absorbé, pour que le reste de l'écran ne réagisse pas
/// pendant le tour — les onglets compris, d'où l'enchaînement par
/// « Suivant ». Composant **contrôlé** : l'étape courante ([index]) est tenue
/// par le parent, seul à savoir quel onglet est affiché sous le halo.
class SpotlightOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final int index;
  final VoidCallback onNext;
  final VoidCallback onDone;

  /// Tap tombé **dans** le halo — le vrai widget l'a reçu aussi. Sert au
  /// parent à réagir à une action qu'il ne peut pas observer autrement (la
  /// dernière étape, dont la cible ouvre un écran plein écran).
  final VoidCallback? onTargetTap;

  const SpotlightOverlay({
    super.key,
    required this.steps,
    required this.index,
    required this.onNext,
    required this.onDone,
    this.onTargetTap,
  });

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<SpotlightOverlay> {
  @override
  void initState() {
    super.initState();
    _ensureTargetVisible();
  }

  @override
  void didUpdateWidget(SpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // L'étape peut changer sans passer par [_next] : le parent la fait
    // avancer quand l'utilisateur touche lui-même la cible.
    if (oldWidget.index != widget.index) _ensureTargetVisible();
  }

  Rect? _targetRect(TourStep step) {
    final ctx = step.targetKey.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(step.padding);
  }

  /// Scrolle la cible de l'étape courante dans le viewport si elle est dans
  /// une liste défilante (ex : le sélecteur de prières peut être sous la ligne
  /// de flottaison sur un petit écran) — sans quoi le halo de surbrillance
  /// pointerait vers du contenu invisible.
  void _ensureTargetVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = widget.steps[widget.index].targetKey.currentContext;
      if (ctx == null) return;
      await Scrollable.ensureVisible(ctx,
          alignment: 0.5, duration: const Duration(milliseconds: 250));
      if (mounted) setState(() {});
    });
  }

  void _next() {
    if (widget.index >= widget.steps.length - 1) {
      widget.onDone();
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[widget.index];
    final rect = _targetRect(step);
    final screen = MediaQuery.of(context).size;
    final palette = context.palette;

    // Bulle au-dessus ou en dessous de la cible selon la place disponible.
    final showBelow = rect == null || rect.center.dy < screen.height / 2;
    final cardTop = rect == null
        ? screen.height / 2 - 80
        : (showBelow ? rect.bottom + 16 : null);
    final cardBottom =
        rect != null && !showBelow ? screen.height - rect.top + 16 : null;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Le voile absorbe les taps partout SAUF dans le halo — c'est
            // `_SpotlightPainter.hitTest` qui le décide, à partir de la même
            // géométrie que celle qu'il peint (coins arrondis compris). Un
            // `IgnorePointer` laisserait tout passer, et découper le voile en
            // bandes rectangulaires autour du halo décrirait la même forme
            // une seconde fois, sans ses arrondis.
            Positioned.fill(
              child: CustomPaint(painter: _SpotlightPainter(rect)),
            ),
            if (rect != null)
              Positioned.fromRect(
                rect: rect,
                // `translucent` : le Listener voit le pointeur ET le laisse
                // continuer vers le widget réel, en dessous dans le Stack de
                // ShellScreen. Un GestureDetector, lui, l'absorberait.
                //
                // Sur `up`, et seulement si le doigt est encore DANS le halo :
                // sur `down`, un appui suivi d'un glissement (scroll démarré
                // sur le bouton) terminait le tour définitivement — il est
                // persisté — alors que le bouton réel n'avait rien reçu.
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerUp: (e) {
                    if (rect.contains(e.position)) widget.onTargetTap?.call();
                  },
                ),
              ),
            Positioned(
              left: 20,
              right: 20,
              top: cardTop,
              bottom: cardBottom,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.surfaceCardSolid,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.cardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.etapeN(widget.index + 1, widget.steps.length),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: palette.gold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step.body,
                      style: TextStyle(fontSize: 13.5, color: palette.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: widget.onDone,
                          child: Text(S.tourPasser),
                        ),
                        FilledButton(
                          onPressed: _next,
                          child: Text(
                            widget.index == widget.steps.length - 1
                                ? S.tourTerminer
                                : S.tourSuivant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Corner radius of the highlight, shared by the paint pass and the hit
/// test — testing a plain Rect while painting a rounded one let taps
/// through the four corners the scrim visibly covers.
const Radius _holeRadius = Radius.circular(16);

class _SpotlightPainter extends CustomPainter {
  final Rect? hole;

  _SpotlightPainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final barrier = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.68);

    if (hole == null) {
      canvas.drawPath(barrier, paint);
      return;
    }

    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(hole!, _holeRadius));
    final result = Path.combine(PathOperation.difference, barrier, holePath);
    canvas.drawPath(result, paint);
  }

  /// `RenderCustomPaint` routes its `hitTestSelf` here: the scrim swallows
  /// everything outside the highlight and lets everything inside through to
  /// the real widget in `ShellScreen`'s stack.
  @override
  bool hitTest(Offset position) {
    final rect = hole;
    if (rect == null) return true;
    return !RRect.fromRectAndRadius(rect, _holeRadius).contains(position);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}
