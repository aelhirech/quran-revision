import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/quran_data.dart';
import '../main.dart';
import '../models/sourate.dart';
import '../models/user_config.dart';
import 'onboarding_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;
  Set<int> _selectedIds = {};
  int _revisionDays = 30;
  String _search = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = context.read<AppState>().config;
    if (config != null && !_editing) {
      _selectedIds = config.learnedSourates.map((s) => s.id).toSet();
      _revisionDays = config.revisionDays;
    }
  }

  List<Sourate> get _filtered => allSourates
      .where((s) =>
          s.nameFr.toLowerCase().contains(_search.toLowerCase()) ||
          s.nameAr.contains(_search) ||
          s.id.toString() == _search)
      .toList();

  Future<void> _save() async {
    final state = context.read<AppState>();
    final sourates =
        allSourates.where((s) => _selectedIds.contains(s.id)).toList();
    await state.saveConfig(UserConfig(
      learnedSourates: sourates,
      revisionDays: _revisionDays,
      startDate: DateTime.now(),
    ));
    if (mounted) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;

    if (state.config == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Mon profil'),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
            actions: [
              if (!_editing)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Modifier',
                  onPressed: () => setState(() => _editing = true),
                )
              else ...[
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _save,
                  child: const Text('Sauver'),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          if (!_editing) _viewBody(cs, state) else _editBody(cs),
        ],
      ),
    );
  }

  Widget _viewBody(ColorScheme cs, AppState state) {
    final config = state.config!;
    final daysElapsed =
        DateTime.now().difference(config.startDate).inDays;
    final daysRemaining =
        (config.revisionDays - daysElapsed).clamp(0, 9999);

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          _infoCard(cs, config, daysElapsed, daysRemaining),
          const SizedBox(height: 16),
          _resetSection(cs, state),
        ]),
      ),
    );
  }

  Widget _infoCard(
      ColorScheme cs, dynamic config, int elapsed, int remaining) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _row(cs, Icons.calendar_today_outlined,
                'Durée objectif', '${config.revisionDays} jours', 0),
            const Divider(height: 24),
            _row(cs, Icons.today_outlined,
                'Jours écoulés', '$elapsed jours', 80),
            const Divider(height: 24),
            _row(cs, Icons.timer_outlined,
                'Jours restants', '$remaining jours', 160),
            const Divider(height: 24),
            _row(cs, Icons.menu_book_outlined, 'Sourates mémorisées',
                '${config.learnedSourates.length}', 240),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.08);
  }

  Widget _row(
      ColorScheme cs, IconData icon, String label, String value, int delayMs) {
    return Row(
      children: [
        Icon(icon, color: cs.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
        ),
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
                fontSize: 15)),
      ],
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs))
        .slideX(begin: 0.05);
  }

  Widget _resetSection(ColorScheme cs, AppState state) {
    return Card(
      elevation: 0,
      color: cs.errorContainer.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(Icons.refresh, color: cs.error),
        title: Text('Réinitialiser la configuration',
            style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        subtitle: const Text('Repart de zéro avec une nouvelle sélection'),
        onTap: () => _showResetDialog(context, state),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  void _showResetDialog(BuildContext context, AppState state) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Réinitialiser ?'),
        content: const Text(
            'La progression du cycle sera perdue. Continue ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                (_) => false,
              );
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  Widget _editBody(ColorScheme cs) {
    return SliverFillRemaining(
      child: Column(
        children: [
          Container(
            color: cs.primaryContainer,
            padding: const EdgeInsets.all(16),
            child: Row(
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
                const Spacer(),
                Text('${_selectedIds.length} sélectionnées',
                    style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
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
        ],
      ),
    );
  }
}
