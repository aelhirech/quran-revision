import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../services/learning_service.dart';
import '../state/app_state.dart';
import '../widgets/daily_verse_info_card.dart';
import '../widgets/learning_progress_card.dart';
import '../widgets/sourate_picker_sheet.dart';
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
        builder: (_) => LearnSurahScreen(progress: p, onChanged: _load),
      ),
    );
    if (result == 'add_to_revision' && mounted) _addToRevision(p.sourate);
    _load();
  }

  Future<void> _addToRevision(Sourate s) async {
    final state = context.read<AppState>();
    final config = state.config;
    if (config == null) return;
    if (config.selections.any((sel) => sel.sourate.id == s.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.nameFr} est déjà dans ta révision')),
      );
      return;
    }
    await state.saveConfig(
        config.copyWith(selections: [...config.selections, SourateSelection.whole(s)]));
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
      builder: (_) => SouratePickerSheet(sourates: available),
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
        content: Text("Supprimer l'apprentissage de ${p.sourate.nameFr} ?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(S.annuler)),
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
                child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const DailyVerseInfoCard(),
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
                        LearningProgressCard(
                          progress: e.value,
                          index: e.key,
                          onTap: () => _openSourate(e.value),
                          onDismiss: () => _deleteLearning(e.value),
                        )),
                  ],
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _startNewSourate,
                    icon: const Icon(Icons.add),
                    label: Text(S.commencerSourate),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                ]),
              ),
            ),
        ],
      ),
    );
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
}
