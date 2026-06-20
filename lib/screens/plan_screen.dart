import 'package:flutter/material.dart';
import '../models/daily_session.dart';
import '../models/prayer.dart';

class PlanScreen extends StatelessWidget {
  final DailySession session;
  final void Function(int unitsCompleted) onComplete;

  const PlanScreen({
    super.key,
    required this.session,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Plan du jour'),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      body: Column(
        children: [
          _summaryBar(cs),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: session.plan
                  .map((pp) => _prayerCard(context, pp, cs))
                  .toList(),
            ),
          ),
          _doneButton(context, cs),
        ],
      ),
    );
  }

  Widget _summaryBar(ColorScheme cs) {
    return Container(
      color: cs.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${session.totalUnits} unités · ${session.totalRakaas} rakaas',
            style: TextStyle(
                color: cs.onPrimaryContainer, fontWeight: FontWeight.bold),
          ),
          Text(
            session.isOnTrack ? '✓ Dans les temps' : '⚠ Prends de l\'avance',
            style: TextStyle(
                color: session.isOnTrack ? Colors.green.shade700 : Colors.orange.shade800,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _prayerCard(BuildContext context, PrayerPlan pp, ColorScheme cs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pp.prayer.nameFr,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                        fontSize: 16)),
                Text(pp.prayer.nameAr,
                    style: TextStyle(
                        color: cs.onSecondaryContainer,
                        fontSize: 18,
                        fontFamily: 'serif')),
              ],
            ),
          ),
          ...pp.rakaas.map((r) => _rakaaRow(r, cs)),
        ],
      ),
    );
  }

  Widget _rakaaRow(RakaaAssignment r, ColorScheme cs) {
    final hasUnit = r.unit != null;
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor:
            hasUnit ? cs.primary : cs.surfaceContainerHighest,
        foregroundColor: hasUnit ? cs.onPrimary : cs.onSurfaceVariant,
        child: Text('${r.rakaaNumber}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
      title: hasUnit
          ? Text(r.unit!.label,
              style: const TextStyle(fontWeight: FontWeight.w500))
          : Text('Al-Fatiha (pas de sourate)',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
      subtitle: hasUnit && !r.unit!.isWhole
          ? Text('${r.unit!.verseCount} versets',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12))
          : null,
      dense: true,
    );
  }

  Widget _doneButton(BuildContext context, ColorScheme cs) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton.icon(
            onPressed: () {
              onComplete(session.totalUnits);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Révision complétée',
                style: TextStyle(fontSize: 16)),
          ),
        ),
      ),
    );
  }
}
