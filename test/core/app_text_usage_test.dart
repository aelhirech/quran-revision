import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// A number right after `fontSize:` is a size written by hand. Computed sizes
// (`size * 0.37`, a `fontSize` parameter) are legitimate and not matched.
final _literalFontSize = RegExp(r'fontSize:\s*\d');

const _themeFile = 'lib/core/app_theme.dart';

// Screens not yet rebuilt on AppText. Remove each entry when its story ships:
// US-23 (Recap and the three cards only it shows).
const _notYetMigrated = [
  'lib/screens/recap_screen.dart',
  'lib/widgets/history_card.dart',
  'lib/widgets/sourates_recap_card.dart',
  'lib/widgets/learning_progress_card.dart',
];

void main() {
  test('aucune taille de police écrite en dur hors du thème (AppText)', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      // listSync returns backslashes on Windows.
      final path = file.path.replaceAll(r'\', '/');
      if (path == _themeFile) continue;
      if (_notYetMigrated.any(path.startsWith)) continue;

      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // Arabic text keeps its own sizes (Amiri, Scheherazade New).
        if (line.contains('GoogleFonts.')) continue;
        if (_literalFontSize.hasMatch(line)) {
          offenders.add('$path:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(offenders, isEmpty,
        reason: 'Utiliser un style d\'AppText (lib/core/app_theme.dart) '
            'plutôt qu\'un fontSize en dur :\n${offenders.join('\n')}');
  });
}
