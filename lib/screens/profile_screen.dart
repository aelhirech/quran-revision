import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/quran_data.dart';
import '../core/revision_engine.dart';
import '../core/strings.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../state/app_state.dart';
import '../widgets/profile_info_card.dart';
import '../widgets/settings_card.dart';

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
      _selectedIds = config.selections.map((s) => s.sourate.id).toSet();
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
    final existingSelections = {
      for (final s in state.config?.selections ?? []) s.sourate.id: s
    };
    final selections = allSourates
        .where((s) => _selectedIds.contains(s.id))
        .map<SourateSelection>(
            (s) => existingSelections[s.id] ?? SourateSelection.whole(s))
        .toList();
    await state.saveConfig(UserConfig(
      selections: selections,
      revisionDays: _revisionDays,
      startDate: state.config?.startDate ?? DateTime.now(),
      shuffleEnabled: state.config?.shuffleEnabled ?? true,
      adaptiveCycle: state.config?.adaptiveCycle ?? false,
    ));
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _showDurationDialog() async {
    int tempDays = _revisionDays;
    final confirmed = await showDialog<int>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(S.modifierDuree),
          content: DropdownButton<int>(
            value: tempDays,
            isExpanded: true,
            items: [7, 14, 21, 30, 60, 90]
                .map((d) => DropdownMenuItem(
                    value: d, child: Text(S.joursDuration(d))))
                .toList(),
            onChanged: (v) => setS(() => tempDays = v!),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.annuler)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, tempDays),
                child: Text(S.sauver)),
          ],
        ),
      ),
    );
    if (confirmed == null || !mounted) return;
    final state = context.read<AppState>();
    await state.saveConfig(state.config!.copyWith(revisionDays: confirmed));
    setState(() => _revisionDays = confirmed);
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
            title: Text(S.monProfil),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
            actions: [
              if (!_editing) ...[
                IconButton(
                  icon: const Icon(Icons.timer_outlined),
                  tooltip: S.modifierDuree,
                  onPressed: _showDurationDialog,
                ),
                IconButton(
                  icon: const Icon(Icons.playlist_add_check_outlined),
                  tooltip: S.modifierSourates,
                  onPressed: () => setState(() => _editing = true),
                ),
              ] else ...[
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  child: Text(S.annuler),
                ),
                FilledButton(
                  onPressed: _selectedIds.isEmpty ? null : _save,
                  child: Text(S.sauver),
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
    final daysElapsed = DateTime.now().difference(config.startDate).inDays;
    final daysRemaining = (config.revisionDays - daysElapsed).clamp(0, 9999);

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          ProfileInfoCard(
              config: config, elapsed: daysElapsed, remaining: daysRemaining),
          const SizedBox(height: 16),
          const SettingsCard(),
          const SizedBox(height: 16),
          _adaptiveCycleCard(cs, state),
          const SizedBox(height: 16),
          _pauseCard(cs, state),
          const SizedBox(height: 16),
          _resetSection(cs, state),
        ]),
      ),
    );
  }

  Widget _adaptiveCycleCard(ColorScheme cs, AppState state) {
    final config = state.config!;
    final isAdaptive = config.adaptiveCycle;
    final estimatedDays = state.adaptiveCycleDays;

    return Card(
      elevation: 0,
      color: isAdaptive
          ? cs.primaryContainer.withValues(alpha: 0.6)
          : cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SwitchListTile.adaptive(
        value: isAdaptive,
        onChanged: (v) => state.setAdaptiveCycle(
          v,
          totalUnits: RevisionEngine.buildUnits(config.selections).length,
        ),
        secondary: Icon(
          Icons.auto_awesome_outlined,
          color: isAdaptive ? cs.primary : cs.onSurfaceVariant,
        ),
        title: Text(S.cycleAdaptatif,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isAdaptive ? cs.onPrimaryContainer : cs.onSurface)),
        subtitle: Text(
          isAdaptive && estimatedDays != null
              ? '${S.cycleEstime(estimatedDays)} · ${S.cycleAdaptatifBase}'
              : S.cycleAdaptatifDesc,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _pauseCard(ColorScheme cs, AppState state) {
    final paused = state.isPausedToday;
    return Card(
      elevation: 0,
      color: paused
          ? cs.tertiaryContainer.withValues(alpha: 0.5)
          : cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SwitchListTile.adaptive(
        value: paused,
        onChanged: (_) => state.togglePauseToday(),
        secondary: Icon(
          Icons.pause_circle_outline,
          color: paused ? cs.tertiary : cs.onSurfaceVariant,
        ),
        title: Text(S.pauseLabel,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: paused ? cs.onTertiaryContainer : cs.onSurface)),
        subtitle: Text(
          paused ? S.pauseActive : S.pauseDesc,
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _resetSection(ColorScheme cs, AppState state) {
    return Card(
      elevation: 0,
      color: cs.errorContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(Icons.refresh, color: cs.error),
        title: Text(S.reinitialiser,
            style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
        subtitle: Text(S.reinitDesc),
        onTap: () => _showResetDialog(state),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  void _showResetDialog(AppState state) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.reinitDialog),
        content: Text(S.reinitConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text(S.annuler)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () async {
              Navigator.pop(context);
              await context.read<AppState>().clearConfig();
            },
            child: Text(S.reinitDialog),
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
                  style: TextStyle(color: cs.onPrimaryContainer),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    if (_selectedIds.length == allSourates.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(allSourates.map((s) => s.id));
                    }
                  }),
                  icon: Icon(
                    _selectedIds.length == allSourates.length
                        ? Icons.deselect
                        : Icons.select_all,
                    color: cs.onPrimaryContainer,
                    size: 16,
                  ),
                  label: Text(
                    _selectedIds.length == allSourates.length
                        ? S.toutDeselectionner
                        : S.toutSelectionner,
                    style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: S.rechercher,
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
                    selected ? _selectedIds.remove(s.id) : _selectedIds.add(s.id);
                  }),
                  title: Text(s.nameFr),
                  subtitle: Text(
                      '${s.nameAr}  ·  ${s.verses} ${S.versetsLabel}'),
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
