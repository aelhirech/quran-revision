import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import '../models/sourate.dart';
import '../models/user_config.dart';
import 'shell_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final Set<int> _selectedIds = {};
  int _revisionDays = 30;
  String _search = '';

  List<Sourate> get _filtered => allSourates
      .where((s) =>
          s.nameFr.toLowerCase().contains(_search.toLowerCase()) ||
          s.nameAr.contains(_search) ||
          s.id.toString() == _search)
      .toList();

  Future<void> _confirm() async {
    if (_selectedIds.isEmpty) return;
    final sourates =
        allSourates.where((s) => _selectedIds.contains(s.id)).toList();
    final config = UserConfig(
      learnedSourates: sourates,
      revisionDays: _revisionDays,
      startDate: DateTime.now(),
    );
    await context.read<AppState>().saveConfig(config);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ShellScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            _header(cs),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
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
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final s = _filtered[i];
                  final selected = _selectedIds.contains(s.id);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (_) => setState(() {
                      selected
                          ? _selectedIds.remove(s.id)
                          : _selectedIds.add(s.id);
                    }),
                    title: Text(s.nameFr),
                    subtitle: Text('${s.nameAr}  ·  ${s.verses} ${S.versetsLabel}'),
                    secondary: CircleAvatar(
                      backgroundColor:
                          selected ? cs.primary : cs.surfaceContainerHighest,
                      foregroundColor:
                          selected ? cs.onPrimary : cs.onSurfaceVariant,
                      radius: 18,
                      child: Text('${s.id}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                  );
                },
              ),
            ),
            _footer(cs),
          ],
        ),
      ),
    );
  }

  Widget _header(ColorScheme cs) {
    final totalVerses = allSourates
        .where((s) => _selectedIds.contains(s.id))
        .fold(0, (sum, s) => sum + s.verses);
    return Container(
      width: double.infinity,
      color: cs.primaryContainer,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.configInitiale,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onPrimaryContainer)),
          const SizedBox(height: 8),
          Text(S.souratesCount(_selectedIds.length, totalVerses),
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: cs.onPrimaryContainer)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(S.reviserEn,
                  style: TextStyle(color: cs.onPrimaryContainer)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _revisionDays,
                items: [7, 14, 21, 30, 60, 90]
                    .map((d) => DropdownMenuItem(
                        value: d, child: Text(S.joursDuration(d))))
                    .toList(),
                onChanged: (v) => setState(() => _revisionDays = v!),
                dropdownColor: cs.primaryContainer,
                style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: _selectedIds.isEmpty ? null : _confirm,
          child: Text(
            _selectedIds.isEmpty ? S.selectSourates : S.commencer,
            style: const TextStyle(fontSize: 16),
          ),
        ),
      ),
    );
  }
}
