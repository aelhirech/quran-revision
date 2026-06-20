import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../core/strings.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../state/app_state.dart';

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            ListTile(
              leading: Icon(Icons.language, color: AppColors.green),
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
            SwitchListTile(
              secondary: Icon(Icons.shuffle, color: AppColors.green),
              title: Text(S.aleatoireLabel),
              subtitle: Text(S.aleatoireSubtitle),
              value: context.watch<AppState>().config?.shuffleEnabled ?? true,
              activeThumbColor: AppColors.green,
              onChanged: (val) => context.read<AppState>().setShuffleEnabled(val),
            ),
            const Divider(height: 1, indent: 56),
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
        ),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _langChip(BuildContext context, String label, String locale, ColorScheme cs) {
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
}
