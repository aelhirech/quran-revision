// One-off data-prep script. Run manually from the project root:
//   dart run tool/prepare_quran_assets.dart
// Not part of the shipped app. Reads the raw QUL downloads
// (assets/quran/qpc-hafs.json, assets/quran/qpc-warsh-script-ayah.json)
// and produces the two assets the app actually bundles:
//   assets/quran/hafs.json   (Hafs text, trailing ayah-numeral stripped)
//   assets/quran/warsh.json  (Warsh text, re-keyed to the same shape)
//
// Both riwayat are kept in their authentic native verse boundaries
// (Hafs 6236 ayat, Warsh 6214 ayat) - no cross-riwaya alignment is
// attempted here. See the plan doc for why: a verse "learned" in Hafs
// text isn't the same memorized content as the same verse in Warsh
// text, so Hafs and Warsh are two independent tracks in the app, not
// translated into each other.

import 'dart:convert';
import 'dart:io';

String stripHafsNumeral(String text) {
  return text.replaceFirst(RegExp(r'\s*[٠-٩]+\s*$'), '').trimRight();
}

Map<String, dynamic> reKey(
  Map<String, dynamic> data, {
  bool stripNumeral = false,
}) {
  final out = <String, dynamic>{};
  for (final v in data.values) {
    final entry = v as Map<String, dynamic>;
    final surah = entry['surah'];
    final ayah = entry['ayah'];
    var text = entry['text'] as String;
    if (stripNumeral) text = stripHafsNumeral(text);
    out['$surah:$ayah'] = {'surah': surah, 'ayah': ayah, 'text': text};
  }
  return out;
}

void main() async {
  final hafsRaw = jsonDecode(
    await File('assets/quran/qpc-hafs.json').readAsString(),
  ) as Map<String, dynamic>;
  final warshRaw = jsonDecode(
    await File('assets/quran/qpc-warsh-script-ayah.json').readAsString(),
  ) as Map<String, dynamic>;

  final hafsOut = reKey(hafsRaw, stripNumeral: true);
  final warshOut = reKey(warshRaw);

  await File('assets/quran/hafs.json').writeAsString(jsonEncode(hafsOut));
  await File('assets/quran/warsh.json').writeAsString(jsonEncode(warshOut));

  print('hafs.json: ${hafsOut.length} ayat');
  print('warsh.json: ${warshOut.length} ayat');
}
