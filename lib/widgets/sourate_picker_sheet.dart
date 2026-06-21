import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/sourate.dart';

class SouratePickerSheet extends StatefulWidget {
  final List<Sourate> sourates;

  const SouratePickerSheet({super.key, required this.sourates});

  @override
  State<SouratePickerSheet> createState() => _SouratePickerSheetState();
}

class _SouratePickerSheetState extends State<SouratePickerSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final filtered = widget.sourates
        .where((s) =>
            s.nameFr.toLowerCase().contains(_search.toLowerCase()) ||
            s.nameAr.contains(_search) ||
            s.id.toString() == _search)
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(S.commencerSourate,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: S.rechercherSourate,
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
                    backgroundColor: AppColors.greenContainer,
                    child: Text('${s.id}',
                        style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                  title: Text(s.nameFr,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${s.nameAr}  ·  ${s.verses} versets'),
                  onTap: () => Navigator.pop(context, s),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
