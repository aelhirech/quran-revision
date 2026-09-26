import 'package:flutter/material.dart';
import '../core/reciters.dart';
import '../core/strings.dart';
import 'draggable_handle.dart';

/// Same chrome as `SouratePickerSheet` (handle + title) — no search field:
/// at most ~28 reciters per riwaya, a short list the user scans at a glance.
class ReciterPickerSheet extends StatelessWidget {
  final List<Reciter> reciters;
  final String? selectedId;

  const ReciterPickerSheet({super.key, required this.reciters, this.selectedId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const DraggableHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(S.choisirRecitateur,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final r in reciters)
                    ListTile(
                      title: Text(r.nameFr),
                      trailing: r.id == selectedId ? const Icon(Icons.check) : null,
                      onTap: () => Navigator.pop(context, r),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
