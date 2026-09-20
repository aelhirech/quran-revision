import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/riwaya.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';
import 'confirm_dialog.dart';

class SettingsCard extends StatefulWidget {
  const SettingsCard({super.key});

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> {
  bool _notifEnabled = true;
  ({int hour, int minute}) _morningTime = (hour: 7, minute: 0);
  ({int hour, int minute}) _eveningTime = (hour: 20, minute: 30);

  @override
  void initState() {
    super.initState();
    StorageService.loadNotifEnabled().then((v) {
      if (mounted) setState(() => _notifEnabled = v);
    });
    StorageService.loadMorningTime().then((t) {
      if (mounted) setState(() => _morningTime = t);
    });
    StorageService.loadEveningTime().then((t) {
      if (mounted) setState(() => _eveningTime = t);
    });
  }

  Future<void> _toggleNotif(bool val) async {
    setState(() => _notifEnabled = val);
    if (val) {
      final granted = await NotificationService.enable();
      // Permission refusée par l'OS : réconcilie le switch avec la réalité
      // au lieu de rester bloqué sur l'état optimiste posé ci-dessus.
      if (mounted && !granted) setState(() => _notifEnabled = false);
    } else {
      await NotificationService.disable();
    }
  }

  String _formatTime(({int hour, int minute}) t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Shared by the two morning/evening pickers — they only differ in the
  /// current time, where to store it locally, and which `StorageService`
  /// method persists the result.
  Future<void> _pickReminderTime({
    required ({int hour, int minute}) current,
    required void Function(({int hour, int minute})) onPicked,
    required Future<void> Function(int hour, int minute) save,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (picked == null || !mounted) return;
    setState(() => onPicked((hour: picked.hour, minute: picked.minute)));
    await save(picked.hour, picked.minute);
    if (_notifEnabled) await NotificationService.rescheduleAll();
  }

  Future<void> _pickMorningTime() => _pickReminderTime(
        current: _morningTime,
        onPicked: (t) => _morningTime = t,
        save: StorageService.saveMorningTime,
      );

  Future<void> _pickEveningTime() => _pickReminderTime(
        current: _eveningTime,
        onPicked: (t) => _eveningTime = t,
        save: StorageService.saveEveningTime,
      );

  Future<void> _toggleShuffle(bool val) async {
    final saved = await context.read<AppState>().setShuffleEnabled(val);
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.configBloqueeJourEnAttente)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: context.palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.palette.cardBorder),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.language, color: cs.primary),
              title: Text(S.langueLabel),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _langChip(context, 'FR', 'fr', cs),
                  const SizedBox(width: 8),
                  _langChip(context, 'EN', 'en', cs),
                ],
              ),
            ),
            const Divider(height: 1, indent: 56),
            ListTile(
              leading: Icon(Icons.menu_book_outlined, color: cs.primary),
              title: Text(S.riwayaLabel),
              subtitle: Text(S.riwayaSubtitle),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _riwayaChip(context, S.hafs, Riwaya.hafs, cs),
                  const SizedBox(width: 8),
                  _riwayaChip(context, S.warsh, Riwaya.warsh, cs),
                ],
              ),
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: Icon(Icons.shuffle, color: cs.primary),
              title: Text(S.aleatoireLabel),
              subtitle: Text(S.aleatoireSubtitle),
              value: context.watch<AppState>().config?.shuffleEnabled ?? true,
              onChanged: _toggleShuffle,
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: Icon(Icons.notifications_outlined, color: cs.primary),
              title: Text(S.notificationsLabel),
              subtitle: Text(S.notifSubtitle),
              value: _notifEnabled,
              onChanged: _toggleNotif,
            ),
            if (_notifEnabled) ...[
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.wb_sunny_outlined, color: cs.primary),
                title: Text(S.rappelMatinLabel),
                trailing: Text(_formatTime(_morningTime),
                    style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                onTap: _pickMorningTime,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.nightlight_outlined, color: cs.primary),
                title: Text(S.rappelSoirLabel),
                trailing: Text(_formatTime(_eveningTime),
                    style: TextStyle(fontWeight: FontWeight.w600, color: cs.primary)),
                onTap: _pickEveningTime,
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Future<void> _switchRiwaya(BuildContext context, Riwaya riwaya) async {
    final state = context.read<AppState>();
    if (state.riwaya == riwaya) return;
    if (riwaya == Riwaya.warsh && !state.warshAvailable) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.warshUnavailable)));
      return;
    }
    final confirmed = await confirmDialog(
      context,
      title: S.switchRiwayaTitle,
      message: S.switchRiwayaConfirm,
      confirmLabel: S.confirmer,
    );
    if (!mounted || !confirmed) return;
    await state.setRiwaya(riwaya);
  }

  Widget _riwayaChip(
      BuildContext context, String label, Riwaya riwaya, ColorScheme cs) {
    final selected = context.watch<AppState>().riwaya == riwaya;
    return GestureDetector(
      onTap: () => _switchRiwaya(context, riwaya),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? cs.primary : context.palette.cardBorder,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            )),
      ),
    );
  }

  Widget _langChip(BuildContext context, String label, String locale, ColorScheme cs) {
    final selected = context.watch<AppState>().locale == locale;
    return GestureDetector(
      onTap: () => context.read<AppState>().setLocale(locale),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? cs.primary : context.palette.cardBorder,
          ),
        ),
        child: Text(label,
            style: TextStyle(
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            )),
      ),
    );
  }
}
