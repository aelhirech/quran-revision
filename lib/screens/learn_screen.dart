import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../services/learning_service.dart';
import '../state/app_state.dart';
import 'learn_surah_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<LearningProgress> _inProgress = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await LearningService.loadAll();
    if (mounted) setState(() { _inProgress = items; _loading = false; });
  }

  Future<void> _openSourate(LearningProgress p) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => LearnSurahScreen(
          progress: p,
          onChanged: _load,
        ),
      ),
    );
    if (result == 'add_to_revision' && mounted) {
      _addToRevision(p.sourate);
    }
    _load();
  }

  Future<void> _addToRevision(Sourate s) async {
    final state = context.read<AppState>();
    final config = state.config;
    if (config == null) return;
    final alreadyIn = config.selections.any((sel) => sel.sourate.id == s.id);
    if (alreadyIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.nameFr} est déjà dans ta révision')),
      );
      return;
    }
    final newSelections = [...config.selections, SourateSelection.whole(s)];
    await state.saveConfig(config.copyWith(selections: newSelections));
    await LearningService.remove(s.id);
    await _load();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.nameFr} ajoutée à la révision ✓')),
      );
    }
  }

  Future<void> _startNewSourate() async {
    final inProgressIds = _inProgress.map((p) => p.sourate.id).toSet();
    final learnedIds = context.read<AppState>().config?.selections
        .map((s) => s.sourate.id).toSet() ?? {};
    final available = allSourates
        .where((s) => !inProgressIds.contains(s.id) && !learnedIds.contains(s.id))
        .toList();

    if (available.isEmpty) return;

    final picked = await showModalBottomSheet<Sourate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SouratePicker(sourates: available),
    );
    if (picked == null) return;

    final p = LearningProgress.start(picked);
    await LearningService.upsert(p);
    await _load();
    if (mounted) _openSourate(p);
  }

  Future<void> _deleteLearning(LearningProgress p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(S.supprimerApprentissage),
        content: Text('Supprimer l\'apprentissage de ${p.sourate.nameFr} ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.annuler)),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LearningService.remove(p.sourate.id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(S.apprentissage),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _dailyVerseInfo(cs),
                  const SizedBox(height: 20),
                  if (_inProgress.isEmpty)
                    _emptyState(cs)
                  else ...[
                    Text(S.enCoursDApprentissage,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: cs.onSurface))
                        .animate().fadeIn(),
                    const SizedBox(height: 12),
                    ..._inProgress.asMap().entries.map((e) =>
                        _progressCard(cs, e.value, e.key)),
                  ],
                  const SizedBox(height: 16),
                  _addButton(cs),
                ]),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dailyVerseInfo(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cs.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_stories, color: cs.onPrimary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('1 verset par jour',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: cs.onPrimaryContainer)),
                const SizedBox(height: 2),
                Text('Mémorise un verset chaque jour et l\'app suit ta progression',
                    style: TextStyle(
                        fontSize: 12,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75))),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.06);
  }

  Widget _emptyState(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined, size: 52, color: cs.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(S.aucuneSourateEnCours,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text(S.aucuneSourateDesc,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
        ],
      ).animate().fadeIn(delay: 100.ms),
    );
  }

  Widget _progressCard(ColorScheme cs, LearningProgress p, int idx) {
    final s = p.sourate;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey(s.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        confirmDismiss: (_) async {
          await _deleteLearning(p);
          return false; // géré manuellement dans _deleteLearning
        },
        child: GestureDetector(
          onTap: () => _openSourate(p),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.greenContainer,
                      child: Text('${s.id}',
                          style: const TextStyle(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.nameFr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15)),
                          Text(s.nameAr,
                              style: TextStyle(
                                  fontSize: 14,
                                  color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    if (p.isComplete)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.greenContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('✓ Complet',
                            style: const TextStyle(
                                color: AppColors.green,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      )
                    else
                      Text(
                        S.versetN(p.nextVerse, s.verses),
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: p.progress,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 6),
                Text(S.versetsAppris(p.learnedCount, s.verses),
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant)),
              ],
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 80 * idx)).slideY(begin: 0.06),
        ),
      ),
    );
  }

  Widget _addButton(ColorScheme cs) {
    return OutlinedButton.icon(
      onPressed: _startNewSourate,
      icon: const Icon(Icons.add),
      label: Text(S.commencerSourate),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _SouratePicker extends StatefulWidget {
  final List<Sourate> sourates;
  const _SouratePicker({required this.sourates});

  @override
  State<_SouratePicker> createState() => _SouratePickerState();
}

class _SouratePickerState extends State<_SouratePicker> {
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
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800)),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12),
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
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
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
