import 'dart:convert';
import 'dart:io';

void main() async {
  // Load the generated Hafs page metadata
  final hafsMetadataJson = await File('assets/quran/metadata/quran-metadata-page-hafs.json').readAsString();
  final hafsMetadata = jsonDecode(hafsMetadataJson) as Map<String, dynamic>;

  // Load surah.json for comparison
  final surahJsonStr = await HttpClient()
      .getUrl(Uri.parse('https://raw.githubusercontent.com/quranpedia/quran-svg/master/mushafs/hafs/kfqc/json/surah.json'))
      .then((req) => req.close())
      .then((resp) => resp.transform(utf8.decoder).join());
  final surahData = jsonDecode(surahJsonStr) as List<dynamic>;

  print('Verifying Hafs page metadata...');
  print('Number of surahs in metadata: ${hafsMetadata.length}');
  print('Number of surahs in surah.json: ${surahData.length}');

  int mismatches = 0;
  for (final surah in surahData) {
    final surahNum = surah['number'] as int;
    final expectedStartPage = surah['pageNumber'] as int;

    final surahMetadata = hafsMetadata[surahNum.toString()] as Map<String, dynamic>?;
    if (surahMetadata == null || surahMetadata.isEmpty) {
      print('Surah $surahNum: Missing metadata');
      mismatches++;
      continue;
    }

    // Get the first ayah's page
    final firstAyahPage = surahMetadata['1'] as int?;
    if (firstAyahPage == null) {
      print('Surah $surahNum: Missing ayah 1');
      mismatches++;
      continue;
    }

    if (firstAyahPage != expectedStartPage) {
      print('Surah $surahNum: Page mismatch - expected $expectedStartPage, got $firstAyahPage');
      mismatches++;
    }
  }

  if (mismatches == 0) {
    print('All surahs match! ✓');
  } else {
    print('Found $mismatches mismatches ✗');
  }
}