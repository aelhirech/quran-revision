import '../models/riwaya.dart';

/// Suffixe une clé de stockage par riwaya — Hafs et Warsh sont deux
/// parcours indépendants, chacun avec ses propres clés. Utilisé par
/// StorageService.
String riwayaKey(String base, Riwaya riwaya) => '${base}_${riwaya.name}';
