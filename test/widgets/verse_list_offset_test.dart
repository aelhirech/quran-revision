import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/widgets/verse_bottom_sheet.dart';

// State trap (see test/CLAUDE.md): narrowing the portion shortens the verse
// list, and the default physics would pull the offset back, moving the slider
// away from the finger (US-31 crit. 4).
void main() {
  // iOS too: its bouncing physics springs back on its own, with no correction.
  testWidgets('a shorter list keeps the offset until the next drag',
      variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
      (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final count = ValueNotifier(300);
    addTearDown(count.dispose);

    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<int>(
        valueListenable: count,
        builder: (_, n, _) => CustomScrollView(
          controller: controller,
          physics: VerseBottomSheet.keepOffsetPhysics(),
          slivers: [
            SliverList.builder(
              itemCount: n,
              itemBuilder: (_, i) => SizedBox(height: 50, child: Text('$i')),
            ),
          ],
        ),
      ),
    ));

    controller.jumpTo(2000);
    await tester.pump();
    count.value = 10;
    // Settle, not a single pump: an idle position springs back over several frames.
    await tester.pumpAndSettle();
    expect(controller.position.pixels, 2000);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -20));
    await tester.pumpAndSettle();
    expect(controller.position.pixels, closeTo(controller.position.maxScrollExtent, 1));
    expect(tester.takeException(), isNull);
  });
}
