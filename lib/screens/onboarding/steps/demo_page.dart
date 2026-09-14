part of '../onboarding_screen.dart';

/// Demo mini-cycle (US-1 criterion 2) — replays the REAL daily gesture (tap
/// "Illuminer ma journée avec le Coran" → pick prayers → see the plan spread
/// across rakaas → "Clôturer ma journée") on FIXED placeholder surahs
/// (An-Nas/Al-Falaq/Al-Ikhlas), never personalized with the user's real
/// selection (it doesn't exist yet at this point in the wizard). Prayers are
/// freely chosen, exactly like the real check-in — user feedback after the
/// first version (fixed Maghrib+Isha, no prayer step) found it didn't feel
/// grounded enough in the real gesture.
///
/// The plan is built in memory via `RevisionEngine`, never persisted and
/// never written to `ayah_facts`: "closing" this fake day is plain local
/// state (`Map<int, Set<int>>`), never an `AppState.checkOut` call.
class _DemoPage extends StatefulWidget {
  final VoidCallback onNext;
  const _DemoPage({required this.onNext});

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  static const _demoSourateIds = {112, 113, 114};

  late final List<RevisionUnit> _units;
  int _step = 0; // 0 = intro/CTA, 1 = pick prayers, 2 = plan + clôture
  final Set<Prayer> _prayers = {};
  int _tahiyyatCount = 0;
  List<PrayerPlan>? _plan;
  List<RevisionUnit> _outside = const [];
  final Map<int, Set<int>> _checkedByPrayer = {};

  List<Prayer> get _effectivePrayers => [
        ...Prayer.values.where((p) => !p.isTahiyyat && _prayers.contains(p)),
        for (int i = 0; i < _tahiyyatCount; i++) Prayer.tahiyyatMasjid,
      ];

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
    _units = _dayUnitsFor(demoConfig).units;
  }

  void _seePlan() {
    final result = RakaaDistributor.distributeToRakaas(
      units: _units,
      prayersAlone: _effectivePrayers,
    );
    setState(() {
      _plan = result.plan;
      _outside = result.outside;
      _step = 2;
    });
  }

  void _toggle(int prayerIndex, int rakaaNumber) {
    setState(() {
      final set = _checkedByPrayer.putIfAbsent(prayerIndex, () => {});
      if (!set.add(rakaaNumber)) set.remove(rakaaNumber);
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case 0:
        return _introStep();
      case 1:
        return _prayersStep();
      default:
        return _planStep();
    }
  }

  Widget _introStep() {
    return SafeArea(
      child: Column(
        children: [
          _OnboardingHeader(title: S.demoTitle, subtitle: S.demoSubtitle),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(
                label: S.illuminerMaJournee,
                icon: Icons.wb_sunny_outlined,
                onPressed: () => setState(() => _step = 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _prayersStep() {
    final palette = context.palette;
    final ready = _effectivePrayers.isNotEmpty;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Text(S.checkInPrieres,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
            child: Text(S.checkInPrieresDesc,
                style: TextStyle(fontSize: 12.5, color: palette.textMuted)),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PrayerSelector(
                selected: _prayers,
                onToggle: (p) => setState(() {
                  _prayers.contains(p) ? _prayers.remove(p) : _prayers.add(p);
                }),
                tahiyyatCount: _tahiyyatCount,
                onTahiyyatCountChanged: (n) =>
                    setState(() => _tahiyyatCount = n),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!ready)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(S.checkInPrieresManquantes,
                        style:
                            TextStyle(fontSize: 11, color: palette.textMuted)),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryCtaButton(
                    label: S.checkInLancerPlan,
                    icon: Icons.check_rounded,
                    onPressed: ready ? _seePlan : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _planStep() {
    final palette = context.palette;
    final plan = _plan!;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(S.demoTitle,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: palette.textPrimary)),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                for (int i = 0; i < plan.length; i++)
                  PrayerPlanCard(
                    prayerIndex: i,
                    pp: plan[i],
                    checked: _checkedByPrayer[i] ?? const {},
                    onToggle: (rakaa) => _toggle(i, rakaa),
                  ),
                OutsidePrayersBlock(units: _outside),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: PrimaryCtaButton(
                label: S.cloturerMaJournee,
                icon: Icons.nightlight_outlined,
                onPressed: widget.onNext,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
