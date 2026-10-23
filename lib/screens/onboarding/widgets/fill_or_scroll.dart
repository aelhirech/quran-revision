part of '../onboarding_screen.dart';

/// Full-height page whose [Spacer]s keep their layout, but which scrolls once
/// the content is taller than the screen (small phone, enlarged text):
/// minHeight + IntrinsicHeight give the Spacers a bounded height to share.
class _FillOrScroll extends StatelessWidget {
  final double horizontalPadding;
  final Widget child;

  const _FillOrScroll({required this.horizontalPadding, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}
