import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/riwaya.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/user_config.dart';
import '../state/app_state.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/preset_dropdown.dart';
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
  int _pagesPerDay = 1;
  String _search = '';
  int _memorisees = 0;
  Riwaya? _lastRiwaya;

  Future<void> _loadMemorisees() async {
    final state = context.read<AppState>();
    final progress = await state.learningProgressList();
    if (!mounted) return;
    setState(() => _memorisees = progress.memorisedCount);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    final config = state.config;
    if (config != null && !_editing) {
      _selectedIds = config.selections.map((s) => s.sourate.id).toSet();
      _pagesPerDay = config.pagesPerDay;
    }
    // Hafs/Warsh ont chacun leur propre progression d'apprentissage — sans ce
    // suivi, changer de riwaya depuis SettingsCard (même écran, ProfileScreen
    // ne quitte jamais l'IndexedStack) laisserait "sourates mémorisées"
    // afficher le compte de l'ancienne riwaya. Même pattern que RecapScreen.
    if (state.riwaya != _lastRiwaya) {
      _lastRiwaya = state.riwaya;
      _loadMemorisees();
    }
  }

  List<Sourate> get _filtered => context
      .read<AppState>()
      .sourates
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
    final selections = state.sourates
        .where((s) => _selectedIds.contains(s.id))
        .map<SourateSelection>(
            (s) => existingSelections[s.id] ?? SourateSelection.whole(s))
        .toList();
    // `copyWith` sur la config existante, jamais un `UserConfig(...)` brut :
    // recopier les champs un à un fait silencieusement retomber au défaut
    // tout champ oublié (c'est arrivé à `versesToLearnPerDay`, Phase 9) et
    // c'est la règle CLAUDE.md « mise à jour uniquement via copyWith() ».
    final existing = state.config;
    await state.saveConfig(existing != null
        ? existing.copyWith(
            selections: selections,
            pagesPerDay: _pagesPerDay,
            riwaya: state.riwaya,
          )
        : UserConfig(
            selections: selections,
            pagesPerDay: _pagesPerDay,
            startDate: DateTime.now(),
            riwaya: state.riwaya,
          ));
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _showDurationDialog() async {
    int tempPages = _pagesPerDay;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(S.modifierDuree),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PresetDropdown(
                value: tempPages,
                presets: pagesPerDayPresets,
                labelBuilder: (n) => '$n ${S.pagesParJourValeur}',
                customDialogTitle: S.pagesCustomTitle,
                customSuffix: S.pagesSuffix,
                onChanged: (v) => setS(() => tempPages = v),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.annuler)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(S.sauver)),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    // Même point d'entrée que la rangée de rythme du check-in : changer le
    // budget de pages régénère la proposition du jour. Passer par
    // `saveConfig` directement laisserait le plan du jour sur l'ancien
    // budget, silencieusement — deux comportements pour le même geste.
    await context.read<AppState>().setPagesPerDay(tempPages);
    if (!mounted) return;
    setState(() {
      _pagesPerDay = tempPages;
    });
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
            title: Text(S.reglages),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
            // Rythme et sourates ne sont plus des boutons d'AppBar (Phase 9
            // Sprint 2) : ce sont deux lignes de `ProfileInfoCard`, la carte
            // qui affiche déjà ces deux valeurs. Ne restent ici que les
            // actions du mode édition, qui n'ont pas de place dans la liste.
            actions: _editing
                ? [
                    TextButton(
                      onPressed: () => setState(() => _editing = false),
                      child: Text(S.annuler),
                    ),
                    FilledButton(
                      onPressed: _selectedIds.isEmpty ? null : _save,
                      child: Text(S.sauver),
                    ),
                    const SizedBox(width: 8),
                  ]
                : null,
          ),
          if (!_editing) _viewBody(cs, state) else _editBody(cs),
        ],
      ),
    );
  }

  Widget _viewBody(ColorScheme cs, AppState state) {
    final config = state.config!;
    final daysElapsed = DateTime.now().difference(config.startDate).inDays;

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          ProfileInfoCard(
            config: config,
            elapsed: daysElapsed,
            memorisees: _memorisees,
            onEditRythme: _showDurationDialog,
            onEditSourates: () => setState(() => _editing = true),
          ),
          const SizedBox(height: 16),
          const SettingsCard(),
          const SizedBox(height: 16),
          _pauseCard(cs, state),
          const SizedBox(height: 16),
          _resetSection(cs, state),
        ]),
      ),
    );
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
    final danger = context.palette.danger;
    return Container(
      decoration: BoxDecoration(
        color: danger.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: danger.withValues(alpha: 0.4)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          leading: Icon(Icons.refresh, color: danger),
          title: Text(S.reinitialiser,
              style: TextStyle(color: danger, fontWeight: FontWeight.w600)),
          subtitle: Text(S.reinitDesc),
          onTap: () => _showResetDialog(state),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Future<void> _showResetDialog(AppState state) async {
    final confirmed = await confirmDialog(
      context,
      title: S.reinitDialog,
      message: S.reinitConfirm,
      confirmLabel: S.reinitDialog,
      danger: true,
    );
    if (confirmed) await state.clearConfig();
  }

  Widget _editBody(ColorScheme cs) {
    final totalSourates = context.watch<AppState>().sourates.length;
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
                // Non-interactif : le rythme s'édite depuis la ligne
                // « Rythme » de la carte parcours — deux façons d'éditer le
                // même réglage sur cette page créait une redondance non
                // harmonisée (retour TestFlight 2026-09-01).
                Text(
                  '$_pagesPerDay ${S.pagesParJourValeur}',
                  style: TextStyle(
                      color: cs.onPrimaryContainer, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => setState(() {
                    if (_selectedIds.length == totalSourates) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds.addAll(
                          context.read<AppState>().sourates.map((s) => s.id));
                    }
                  }),
                  icon: Icon(
                    _selectedIds.length == totalSourates
                        ? Icons.deselect
                        : Icons.select_all,
                    color: cs.onPrimaryContainer,
                    size: 16,
                  ),
                  label: Text(
                    _selectedIds.length == totalSourates
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
