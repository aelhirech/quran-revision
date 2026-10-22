import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_revision/core/app_colors.dart';
import 'package:quran_revision/core/app_theme.dart';

// WCAG 2.1 relative luminance, written out here rather than borrowed from
// `Color.computeLuminance` so the test states the rule it checks.
double _luminance(Color color) {
  double channel(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) + 0.7152 * channel(color.g) + 0.0722 * channel(color.b);
}

/// Contrast of [fg] drawn on the opaque [bg]; a translucent [fg] is composited first.
double _contrast(Color fg, Color bg) {
  final a = _luminance(Color.alphaBlend(fg, bg));
  final b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

void main() {
  for (final (name, palette) in [('light', AppPalette.light), ('dark', AppPalette.dark)]) {
    group('$name palette', () {
      final background = palette.cream;
      // Cards are translucent: what the eye sees is the card over the background.
      final card = Color.alphaBlend(palette.surfaceCard, background);
      final texts = {
        'textPrimary': palette.textPrimary,
        'textMuted': palette.textMuted,
        'primary': palette.primary,
        'danger': palette.danger,
        'goldDark': palette.goldDark,
        'onSurfaceVariant': palette.onSurfaceVariant,
      };

      texts.forEach((token, color) {
        test('$token reaches 4.5:1 on the background and on a card', () {
          expect(_contrast(color, background), greaterThanOrEqualTo(4.5));
          expect(_contrast(color, card), greaterThanOrEqualTo(4.5));
        });
      });

      test('risk and the five level tints reach 3:1 on the background and on a card', () {
        expect(palette.levelTints, hasLength(5));
        for (final shape in [palette.risk, ...palette.levelTints]) {
          expect(_contrast(shape, background), greaterThanOrEqualTo(3.0), reason: '$shape');
          expect(_contrast(shape, card), greaterThanOrEqualTo(3.0), reason: '$shape on a card');
        }
      });
    });
  }

  test('buildAppTheme sets Outfit on the text theme in both brightnesses', () {
    for (final brightness in Brightness.values) {
      final textTheme = buildAppTheme(brightness).textTheme;
      for (final style in [
        textTheme.headlineMedium,
        textTheme.labelSmall,
        textTheme.titleMedium,
        textTheme.bodyLarge,
        textTheme.bodyMedium,
        textTheme.bodySmall,
        textTheme.displayMedium,
      ]) {
        expect(style?.fontFamily, AppText.family);
      }
      expect(textTheme.headlineMedium?.fontSize, AppText.screenTitle.fontSize);
      expect(textTheme.bodyMedium?.fontSize, AppText.body.fontSize);
    }
  });
}
