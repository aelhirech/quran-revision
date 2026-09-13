part of '../onboarding_screen.dart';

/// Demo mini-cycle (US-1 criterion 2) — FIXED placeholder surahs (An-Nas/
/// Al-Falaq/Al-Ikhlas), never personalized with the user's real selection
/// (it doesn't exist yet at this point in the wizard). The plan is built in
/// memory via `RevisionEngine`, never persisted and never written to
/// `ayah_facts`: "closing" this fake day is plain local state
/// (`Map<int, Set<int>>`), never an `AppState.checkOut` call.
///
/// These 3 surahs all sit on the same mushaf page (604, verified for both
/// Hafs and Warsh) — one single cycle entry — and Maghrib+Isha give 4
/// recited rakaas, comfortably enough to never leave content "outside
/// prayers" (checked against `RevisionEngine.distributeToRakaas`).
class _DemoPage extends StatefulWidget {
  final VoidCallback onNext;
  const _DemoPage({required this.onNext});

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  static const _demoSourateIds = {112, 113, 114};
  static const _demoPrayers = [Prayer.maghrib, Prayer.isha];

  late final List<PrayerPlan> _plan;
  final Map<int, Set<int>> _checkedByPrayer = {};

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    final sourates = state.sourates
        .where((s) => _demoSourateIds.contains(s.id))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    final demoConfig = UserConfig(
      selections: [for (final s in sourates) SourateSelection.whole(s)],
      pagesPerDay: 1,
      startDate: DateTime.now(),
      shuffleEnabled: false,
      riwaya: state.riwaya,
    );
    _plan = RevisionEngine.distributeToRakaas(
      units: _dayUnitsFor(demoConfig).units,
      prayersAlone: _demoPrayers,
    ).plan;
  }

  void _toggle(int prayerIndex, int rakaaNumber) {
    setState(() {
      final set = _checkedByPrayer.putIfAbsent(prayerIndex, () => {});
      if (!set.add(rakaaNumber)) set.remove(rakaaNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _OnboardingListStep(
      title: S.demoTitle,
      subtitle: S.demoSubtitle,
      ctaLabel: S.cloturerMaJournee,
      ctaIcon: Icons.nightlight_outlined,
      onCta: widget.onNext,
      children: [
        for (int i = 0; i < _plan.length; i++)
          PrayerPlanCard(
            prayerIndex: i,
            pp: _plan[i],
            checked: _checkedByPrayer[i] ?? const {},
            onToggle: (rakaa) => _toggle(i, rakaa),
          ),
      ],
    );
  }
}
