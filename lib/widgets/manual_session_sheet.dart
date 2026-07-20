import 'package:flutter/material.dart';
import '../core/strings.dart';
import 'primary_cta_button.dart';

class ManualSessionSheet extends StatefulWidget {
  final int maxUnits;

  const ManualSessionSheet({super.key, required this.maxUnits});

  @override
  State<ManualSessionSheet> createState() => _ManualSessionSheetState();
}

class _ManualSessionSheetState extends State<ManualSessionSheet> {
  int _units = 1;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            S.saisieManuelle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.saisieManuelleDesc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          Text(
            S.unitesRevisees,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                onPressed: _units > 1 ? () => setState(() => _units--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  '$_units',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed: _units < widget.maxUnits
                    ? () => setState(() => _units++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryCtaButton(
            label: S.loggerSession,
            onPressed: () => Navigator.pop(context, _units),
          ),
        ],
      ),
    );
  }
}
