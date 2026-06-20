import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../state/app_state.dart';
import '../models/sourate.dart';
import '../models/user_config.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

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
            title: Text(S.monProfil),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
            actions: [
              if (!_editing)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: S.modifier,
                  onPressed: () => setState(() => _editing = true),
                )
              else ...[
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
          _settingsCard(cs),
          const SizedBox(height: 16),
          _resetSection(cs, state),
        ]),
      ),
    );
  }

  Widget _infoCard(
      ColorScheme cs, UserConfig config, int elapsed, int remaining) {
    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _row(cs, Icons.calendar_today_outlined,
                S.dureeObjectif, S.joursDuration(config.revisionDays), 0),
            const Divider(height: 24),
            _row(cs, Icons.today_outlined,
                S.joursEcoules, S.joursDuration(elapsed), 80),
            const Divider(height: 24),
            _row(cs, Icons.timer_outlined,
                S.joursRestantsLabel, S.joursDuration(remaining), 160),
            const Divider(height: 24),
            _row(cs, Icons.menu_book_outlined,
                S.souratesMemoriees, '${config.learnedSourates.length}', 240),
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

  Widget _settingsCard(ColorScheme cs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
        children: [
          // Langue
          ListTile(
            leading: Icon(Icons.language, color: AppColors.green),
            title: Text(S.langueLabel),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _langChip('FR', 'fr', cs),
                const SizedBox(width: 8),
                _langChip('EN', 'en', cs),
              ],
            ),
          ),
          const Divider(height: 1, indent: 56),
          // Ordre aléatoire
          SwitchListTile(
            secondary: Icon(Icons.shuffle, color: AppColors.green),
            title: Text(S.aleatoireLabel),
            subtitle: Text(S.aleatoireSubtitle),
            value: context.watch<AppState>().config?.shuffleEnabled ?? true,
            activeThumbColor: AppColors.green,
            onChanged: (val) => context.read<AppState>().setShuffleEnabled(val),
          ),
          const Divider(height: 1, indent: 56),
          // Notifications
          StatefulBuilder(builder: (ctx, setSt) {
            return FutureBuilder<bool>(
              future: StorageService.loadNotifEnabled(),
              builder: (_, snap) {
                final enabled = snap.data ?? true;
                return SwitchListTile(
                  secondary: Icon(Icons.notifications_outlined,
                      color: AppColors.green),
                  title: Text(S.notificationsLabel),
                  subtitle: Text(S.notifSubtitle),
                  value: enabled,
                  activeThumbColor: AppColors.green,
                  onChanged: (val) async {
                    await StorageService.saveNotifEnabled(val);
                    if (val) {
                      await NotificationService.requestPermission();
                      await NotificationService.scheduleMorning();
                      await NotificationService.scheduleEvening();
                    } else {
                      await NotificationService.cancelAll();
                    }
                    setSt(() {});
                  },
                );
              },
            );
          }),
        ],
      )),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _langChip(String label, String locale, ColorScheme cs) {
    final selected = context.watch<AppState>().locale == locale;
    return GestureDetector(
      onTap: () => context.read<AppState>().setLocale(locale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.green : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? AppColors.green : AppColors.cardBorder,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? Colors.white : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            )),
      ),
    );
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
        onTap: () => _showResetDialog(context, state),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  void _showResetDialog(BuildContext context, AppState state) {
    final cs = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.reinitDialog),
        content: Text(S.reinitConfirm),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(S.annuler)),
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
                Text(S.reviserEn, style: TextStyle(color: cs.onPrimaryContainer)),
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
        ],
      ),
    );
  }
}


