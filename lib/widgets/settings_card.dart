import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../models/riwaya.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';

class SettingsCard extends StatefulWidget {
  const SettingsCard({super.key});

  @override
  State<SettingsCard> createState() => _SettingsCardState();
}

class _SettingsCardState extends State<SettingsCard> {
  bool _notifEnabled = true;

  @override
  void initState() {
    super.initState();
    StorageService.loadNotifEnabled().then((v) {
      if (mounted) setState(() => _notifEnabled = v);
    });
  }

  Future<void> _toggleNotif(bool val) async {
    setState(() => _notifEnabled = val);
    await StorageService.saveNotifEnabled(val);
    if (val) {
      await NotificationService.requestPermission();
      await NotificationService.scheduleMorning();
      await NotificationService.scheduleEvening();
    } else {
      await NotificationService.cancelAll();
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
              onChanged: (val) => context.read<AppState>().setShuffleEnabled(val),
            ),
            const Divider(height: 1, indent: 56),
            SwitchListTile(
              secondary: Icon(Icons.notifications_outlined, color: cs.primary),
              title: Text(S.notificationsLabel),
              subtitle: Text(S.notifSubtitle),
              value: _notifEnabled,
              onChanged: _toggleNotif,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _riwayaChip(
      BuildContext context, String label, Riwaya riwaya, ColorScheme cs) {
    final selected = context.watch<AppState>().riwaya == riwaya;
    return GestureDetector(
      onTap: () => context.read<AppState>().setRiwaya(riwaya),
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
