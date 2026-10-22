import 'package:quran_revision/state/app_state.dart';

/// What pressing « Illuminer ma journée » then validating the check-in
/// unchanged does: the only way today's plan reaches `ayah_facts`.
Future<void> validateCheckIn(AppState state) async =>
    state.commitCheckIn(await state.checkInStart());
