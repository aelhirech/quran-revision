import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/quran_data.dart';
import '../core/strings.dart';
import '../models/learning_progress.dart';
import '../models/sourate.dart';
import '../models/sourate_selection.dart';
import '../models/student_profile.dart';
import '../services/learning_service.dart';
import '../services/student_service.dart';
import '../state/app_state.dart';
import '../widgets/daily_verse_info_card.dart';
import '../widgets/learning_progress_card.dart';
import '../widgets/sourate_picker_sheet.dart';
import '../widgets/student_profile_bar.dart';
import 'learn_surah_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  List<LearningProgress> _inProgress = [];
  List<StudentProfile> _students = [];
  String? _activeStudentId; // null = profil principal
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final students = await StudentService.loadProfiles();
    final items = await _loadProgress();
    if (mounted) {
      setState(() {
        _students = students;
        _inProgress = items;
        _loading = false;
      });
    }
  }

  Future<List<LearningProgress>> _loadProgress() async {
    if (_activeStudentId == null) {
      return LearningService.loadAll();
    }
    return StudentService.loadProgress(_activeStudentId!);
  }

  Future<void> _reload() async {
    final items = await _loadProgress();
    if (mounted) setState(() => _inProgress = items);
  }

  Future<void> _switchProfile(String? id) async {
    setState(() {
      _activeStudentId = id;
      _loading = true;
    });
    final items = await _loadProgress();
    if (mounted) setState(() { _inProgress = items; _loading = false; });
  }

  Future<void> _addStudent() async {
    final name = await _showNameDialog();
    if (name == null || name.trim().isEmpty) return;
    final profile = await StudentService.addProfile(name.trim());
    if (mounted) setState(() => _students = [..._students, profile]);
    await _switchProfile(profile.id);
  }

  Future<void> _deleteStudent(StudentProfile p) async {
    await StudentService.removeProfile(p.id);
    final students = await StudentService.loadProfiles();
    if (mounted) setState(() => _students = students);
    if (_activeStudentId == p.id) await _switchProfile(null);
  }

  Future<String?> _showNameDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(S.nomEleve),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(hintText: S.ajouterEleveHint),
            textCapitalization: TextCapitalization.words,
            onSubmitted: (v) => Navigator.pop(context, v),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.annuler)),
            FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(S.ajouter)),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _openSourate(LearningProgress p) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => LearnSurahScreen(
          progress: p,
          onChanged: _reload,
          studentId: _activeStudentId,
        ),
      ),
    );
    if (result == 'add_to_revision' && mounted && _activeStudentId == null) {
      _addToRevision(p.sourate);
    }
    _reload();
  }

  Future<void> _addToRevision(Sourate s) async {
    final state = context.read<AppState>();
    final config = state.config;
    if (config == null) return;
    if (config.selections.any((sel) => sel.sourate.id == s.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.nameFr} ${S.dejaInRevision}')),
      );
      return;
    }
    await state.saveConfig(
        config.copyWith(selections: [...config.selections, SourateSelection.whole(s)]));
    await LearningService.remove(s.id);
    await _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.nameFr} ${S.ajouteARevision}')),
      );
    }
  }

  Future<void> _startNewSourate() async {
    final inProgressIds = _inProgress.map((p) => p.sourate.id).toSet();
    final learnedIds = _activeStudentId == null
        ? (context.read<AppState>().config?.selections
                .map((s) => s.sourate.id)
                .toSet() ??
            {})
        : <int>{};
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
    if (_activeStudentId == null) {
      await LearningService.upsert(p);
    } else {
      await StudentService.upsertProgress(_activeStudentId!, p);
    }
    await _reload();
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
            child: Text(S.supprimer),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      if (_activeStudentId == null) {
        await LearningService.remove(p.sourate.id);
      } else {
        await StudentService.removeProgress(_activeStudentId!, p.sourate.id);
      }
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch pour rebuildler quand la locale change (titre et strings)
    context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final studentName = _activeStudentId == null
        ? null
        : _students.where((s) => s.id == _activeStudentId).firstOrNull?.name;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Text(studentName != null
                ? '${S.apprentissage} · $studentName'
                : S.apprentissage),
            backgroundColor: cs.surface,
            foregroundColor: cs.onSurface,
            centerTitle: false,
          ),
          SliverToBoxAdapter(
            child: StudentProfileBar(
              profiles: _students,
              activeId: _activeStudentId,
              onSelect: _switchProfile,
              onAdd: _addStudent,
              onDelete: _deleteStudent,
            ),
          ),
          if (_students.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 0),
                child: Text(S.longPressEleveHint,
                    style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.55))),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_activeStudentId == null) ...[
                    const DailyVerseInfoCard(),
                    const SizedBox(height: 20),
                  ],
                  if (_inProgress.isEmpty)
                    _emptyState(cs)
                  else ...[
                    Text(S.enCoursDApprentissage,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: cs.onSurface))
                        .animate()
                        .fadeIn(),
                    const SizedBox(height: 12),
                    ..._inProgress.asMap().entries.map((e) =>
                        LearningProgressCard(
                          progress: e.value,
                          index: e.key,
                          onTap: () => _openSourate(e.value),
                          onDismiss: () => _deleteLearning(e.value),
                        )),
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Text(S.swipeSupprimer,
                          style: TextStyle(
                              fontSize: 11,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.55))),
                    ),
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
