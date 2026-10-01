import 'package:flutter/material.dart';
import '../core/strings.dart';
import 'outlined_action_button.dart';

/// "Back + main action" footer shared by the check-in and check-out steps
/// (US-15 crit. 3), so moving between steps looks and behaves the same in
/// both rituals. [onBack] null = first step, no back button. [hint] is an
/// optional line above the buttons (e.g. why the action is disabled).
class StepFooter extends StatelessWidget {
  final VoidCallback? onBack;
  final Widget primary;
  final Widget? hint;

  const StepFooter({super.key, this.onBack, required this.primary, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hint != null)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: hint),
          SizedBox(
            height: 54,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (onBack != null) ...[
                  Expanded(
                    child: OutlinedActionButton(
                        icon: Icons.arrow_back,
                        label: SCheckIn.retour,
                        onTap: onBack!),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(flex: 2, child: primary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
