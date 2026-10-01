import 'package:flutter/material.dart';
import '../core/strings.dart';
import '../models/sourate.dart';

class SouratePickerSheet extends StatefulWidget {
  final List<Sourate> sourates;

  /// Titre de la feuille — le picker sert à trois gestes différents
  /// (démarrer une mémorisation, choisir la sourate à apprendre aujourd'hui,
  /// déclarer une sourate révisée en plus au check-out) ; laisser
  /// « Commencer une sourate » codé en dur mentait dans deux cas sur trois.
  final String? title;

  const SouratePickerSheet(
      {super.key, required this.sourates, this.title});

  @override
  State<SouratePickerSheet> createState() => _SouratePickerSheetState();
}

class _SouratePickerSheetState extends State<SouratePickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered =
        widget.sourates.where((s) => s.matchesSearch(_search)).toList();

    // A Material (not a decorated Container) so the ListTiles' ink splash is
    // painted on this surface instead of under it — invisible otherwise.
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.80,
      child: Material(
        color: cs.surface,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(widget.title ?? S.commencerSourate,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(
                  hintText: SOnboarding.rechercherSourate,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text('${s.id}',
                          style: TextStyle(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12)),
                    ),
                    title: Text(s.nameFr,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    // Arabic last: placed first, the bidi algorithm pulled the
                    // count to its left ("286 · البقرة versets").
                    subtitle: Text('${S.versetsCount(s.verses)}  ·  ${s.nameAr}'),
                    onTap: () => Navigator.pop(context, s),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
