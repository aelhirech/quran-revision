import 'package:flutter/material.dart';
import '../core/strings.dart';

const int _customSentinel = -1;

/// Dropdown numérique avec valeurs prédéfinies + option "Personnalisé…"
/// ouvrant un dialog de saisie libre. Utilisé pour la durée du cycle et le
/// rythme en lignes/jour (profil + onboarding).
class PresetDropdown extends StatelessWidget {
  final int value;
  final List<int> presets;
  final ValueChanged<int> onChanged;
  final String Function(int) labelBuilder;
  final String customDialogTitle;
  final String customSuffix;
  final Color? color;
  final Color? dropdownColor;

  const PresetDropdown({
    super.key,
    required this.value,
    required this.presets,
    required this.onChanged,
    required this.labelBuilder,
    required this.customDialogTitle,
    required this.customSuffix,
    this.color,
    this.dropdownColor,
  });

  Future<void> _pickCustom(BuildContext context) async {
    final isPreset = presets.contains(value);
    final controller =
        TextEditingController(text: isPreset ? '' : '$value');
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(suffixText: customSuffix),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(S.annuler)),
          FilledButton(
            onPressed: () {
              final n = int.tryParse(controller.text);
              Navigator.pop(ctx, (n != null && n > 0) ? n : null);
            },
            child: Text(S.sauver),
          ),
        ],
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final items = {...presets, if (!presets.contains(value)) value}.toList()
      ..sort();
    return DropdownButton<int>(
      value: value,
      isExpanded: false,
      underline: const SizedBox(),
      dropdownColor: dropdownColor,
      items: [
        ...items.map((d) => DropdownMenuItem(
              value: d,
              child: Text(labelBuilder(d),
                  style: TextStyle(fontWeight: FontWeight.w700, color: color)),
            )),
        DropdownMenuItem(
          value: _customSentinel,
          child: Text(S.dureePersonnalisee, style: TextStyle(color: color)),
        ),
      ],
      onChanged: (v) {
        if (v == null) return;
        if (v == _customSentinel) {
          _pickCustom(context);
        } else {
          onChanged(v);
        }
      },
    );
  }
}
