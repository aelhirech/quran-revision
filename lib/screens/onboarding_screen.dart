import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/quran_data.dart';
import '../main.dart';
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
      appBar: AppBar(
        title: const Text('Configuration initiale'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Column(
        children: [
          _header(cs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher une sourate...',
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
                  subtitle: Text('${s.nameAr}  ·  ${s.verses} versets'),
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
    );
  }

  Widget _header(ColorScheme cs) {
    final total = allSourates
        .where((s) => _selectedIds.contains(s.id))
        .fold(0, (sum, s) => sum + s.verses);
    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedIds.length} sourates sélectionnées · $total versets',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Réviser en ', style: TextStyle(color: cs.onPrimaryContainer)),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: _revisionDays,
                items: [7, 14, 21, 30, 60, 90]
                    .map((d) => DropdownMenuItem(
                        value: d, child: Text('$d jours')))
                    .toList(),
                onChanged: (v) => setState(() => _revisionDays = v!),
                dropdownColor: cs.primaryContainer,
                style: TextStyle(color: cs.onPrimaryContainer),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer(ColorScheme cs) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: _selectedIds.isEmpty ? null : _confirm,
            child: Text(
              _selectedIds.isEmpty
                  ? 'Sélectionne tes sourates'
                  : 'Commencer la révision',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
