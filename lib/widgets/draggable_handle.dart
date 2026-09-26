import 'package:flutter/material.dart';

/// The small rounded bar at the top of a draggable bottom sheet, signalling
/// it can be dragged/dismissed. Shared by `VerseBottomSheet` and
/// `ReciterPickerSheet` — the two newest sheets to need it.
class DraggableHandle extends StatelessWidget {
  const DraggableHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: cs.onSurfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
