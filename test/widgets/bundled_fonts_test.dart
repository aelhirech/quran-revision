import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Same setting as lib/main.dart: a missing or renamed file in assets/fonts/
  // makes pendingFonts throw instead of silently falling back to the system font.
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('Amiri et Scheherazade New se chargent depuis les assets, sans réseau',
      () async {
    await expectLater(
      GoogleFonts.pendingFonts([
        GoogleFonts.amiri(),
        GoogleFonts.scheherazadeNew(),
      ]),
      completes,
    );
  });
}
