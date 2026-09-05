import 'dart:convert';
import 'dart:io';

void main() async {
  // Load the existing hafs.json to get verse counts
  final hafsJson = await File('assets/quran/hafs.json').readAsString();
  final hafsData = jsonDecode(hafsJson) as Map<String, dynamic>;

  // Build verse counts map for Hafs (surah -> verse count)
  final Map<int, int> hafsVerseCounts = {};
  hafsData.forEach((key, value) {
    final parts = key.split(':');
    final surah = int.parse(parts[0]);
    // We'll count verses per surah by finding the max ayah number for each surah
    final ayah = int.parse(parts[1]);
    if (!hafsVerseCounts.containsKey(surah) || ayah > hafsVerseCounts[surah]!) {
      hafsVerseCounts[surah] = ayah;
    }
  });

  // Load the existing warsh.json to get verse counts
  final warshJson = await File('assets/quran/warsh.json').readAsString();
  final warshData = jsonDecode(warshJson) as Map<String, dynamic>;

  // Build verse counts map for Warsh (surah -> verse count)
  final Map<int, int> warshVerseCounts = {};
  warshData.forEach((key, value) {
    final parts = key.split(':');
    final surah = int.parse(parts[0]);
    // We'll count verses per surah by finding the max ayah number for each surah
    final ayah = int.parse(parts[1]);
    if (!warshVerseCounts.containsKey(surah) || ayah > warshVerseCounts[surah]!) {
      warshVerseCounts[surah] = ayah;
    }
  });

  // Function to convert global ayah number to (surah, ayah_in_surah) for a given verse count map
  (int surah, int ayahInSurah) convertGlobalAyah(int globalAyah, Map<int, int> verseCounts) {
    int remaining = globalAyah;
    // Sort surahs by number to process in order
    final sortedSurahs = verseCounts.keys.toList()..sort();
    for (final surahNum in sortedSurahs) {
      final verseCount = verseCounts[surahNum]!;
      if (remaining <= verseCount) {
        return (surahNum, remaining);
      }
      remaining -= verseCount;
    }
    throw ArgumentError('Global ayah $globalAyah out of range');
  }

  // Process Hafs
  print('Processing Hafs...');
  final hafsMarkersJson = await HttpClient()
      .getUrl(Uri.parse('https://raw.githubusercontent.com/quranpedia/quran-svg/master/mushafs/hafs/kfqc/json/markers.json'))
      .then((req) => req.close())
      .then((resp) => resp.transform(utf8.decoder).join());
  final hafsMarkers = jsonDecode(hafsMarkersJson) as List<dynamic>;

  final Map<int, Map<int, int>> hafsPageMap = {}; // surah -> {ayah -> page}
  for (final marker in hafsMarkers) {
    final globalAyah = marker['ayah'] as int;
    final page = marker['page'] as int;
    final (surah, ayahInSurah) = convertGlobalAyah(globalAyah, hafsVerseCounts);

    if (!hafsPageMap.containsKey(surah)) {
      hafsPageMap[surah] = <int, int>{};
    }
    hafsPageMap[surah]![ayahInSurah] = page;
  }

  // Save Hafs metadata
  final Map<String, dynamic> hafsMetadata = <String, dynamic>{};
  hafsPageMap.forEach((surah, ayahMap) {
    final Map<String, dynamic> ayahMapStr = <String, dynamic>{};
    ayahMap.forEach((ayah, page) {
      ayahMapStr[ayah.toString()] = page;
    });
    hafsMetadata[surah.toString()] = ayahMapStr;
  });
  await File('assets/quran/metadata/quran-metadata-page-hafs.json')
      .writeAsString(JsonEncoder.withIndent('  ').convert(hafsMetadata));
  print('Hafs metadata saved: ${hafsPageMap.length} surahs');

  // Process Warsh
  print('Processing Warsh...');
  final warshMarkersJson = await HttpClient()
      .getUrl(Uri.parse('https://raw.githubusercontent.com/quranpedia/quran-svg/master/mushafs/warsh/kfqc/json/markers.json'))
      .then((req) => req.close())
      .then((resp) => resp.transform(utf8.decoder).join());
  final warshMarkers = jsonDecode(warshMarkersJson) as List<dynamic>;

  final Map<int, Map<int, int>> warshPageMap = {}; // surah -> {ayah -> page}
  for (final marker in warshMarkers) {
    final globalAyah = marker['ayah'] as int;
    final page = marker['page'] as int;
    final (surah, ayahInSurah) = convertGlobalAyah(globalAyah, warshVerseCounts);

    if (!warshPageMap.containsKey(surah)) {
      warshPageMap[surah] = <int, int>{};
    }
    warshPageMap[surah]![ayahInSurah] = page;
  }

  // Save Warsh metadata
  final Map<String, dynamic> warshMetadata = <String, dynamic>{};
  warshPageMap.forEach((surah, ayahMap) {
    final Map<String, dynamic> ayahMapStr = <String, dynamic>{};
    ayahMap.forEach((ayah, page) {
      ayahMapStr[ayah.toString()] = page;
    });
    warshMetadata[surah.toString()] = ayahMapStr;
  });
  await File('assets/quran/metadata/quran-metadata-page-warsh.json')
      .writeAsString(JsonEncoder.withIndent('  ').convert(warshMetadata));
  print('Warsh metadata saved: ${warshPageMap.length} surahs');

  print('Done!');
}