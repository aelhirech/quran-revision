import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';

/// Clés stables des éléments pointés par le tour guidé — attachées via
/// [KeyedSubtree] aux widgets réels dans HomeScreen/ShellScreen, sans avoir
/// à faire remonter de GlobalKey à travers les constructeurs.
class TourKeys {
  static final navBar = GlobalKey();
  static final prayerSelector = GlobalKey();
  static final voirPlanButton = GlobalKey();
}

class TourStep {
  final GlobalKey targetKey;
  final String title;
  final String body;

  const TourStep({required this.targetKey, required this.title, required this.body});
}

/// Tour guidé avec surbrillance : assombrit l'écran sauf autour du widget
/// ciblé par l'étape courante, avec une bulle d'explication et des contrôles
/// Suivant/Passer. Ne nécessite aucune dépendance externe — juste les
/// GlobalKeys déjà posées sur les widgets à mettre en avant.
class SpotlightOverlay extends StatefulWidget {
  final List<TourStep> steps;
  final VoidCallback onDone;

  const SpotlightOverlay({super.key, required this.steps, required this.onDone});

  @override
  State<SpotlightOverlay> createState() => _SpotlightOverlayState();
}

class _SpotlightOverlayState extends State<SpotlightOverlay> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _ensureTargetVisible();
  }

  Rect? _targetRect(GlobalKey key) {
    final ctx = key.currentContext;
    final box = ctx?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(8);
  }

  /// Scrolle la cible de l'étape courante dans le viewport si elle est dans
  /// une liste défilante (ex : le sélecteur de prières peut être sous la ligne
  /// de flottaison sur un petit écran) — sans quoi le halo de surbrillance
  /// pointerait vers du contenu invisible.
  void _ensureTargetVisible() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ctx = widget.steps[_index].targetKey.currentContext;
      if (ctx == null) return;
      await Scrollable.ensureVisible(ctx,
          alignment: 0.5, duration: const Duration(milliseconds: 250));
      if (mounted) setState(() {});
    });
  }

  void _next() {
    if (_index >= widget.steps.length - 1) {
      widget.onDone();
    } else {
      setState(() => _index++);
      _ensureTargetVisible();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final rect = _targetRect(step.targetKey);
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
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _SpotlightPainter(rect),
                ),
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
                      S.etapeN(_index + 1, widget.steps.length),
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
                            _index == widget.steps.length - 1
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
      ..addRRect(RRect.fromRectAndRadius(hole!, const Radius.circular(16)));
    final result = Path.combine(PathOperation.difference, barrier, holePath);
    canvas.drawPath(result, paint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) =>
      oldDelegate.hole != hole;
}
