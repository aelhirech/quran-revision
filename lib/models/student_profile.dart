import 'dart:convert';

class StudentProfile {
  final String id;
  final String name;

  const StudentProfile({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory StudentProfile.fromJson(Map<String, dynamic> j) =>
      StudentProfile(id: j['id'] as String, name: j['name'] as String);

  static List<StudentProfile> listFromJson(String raw) {
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => StudentProfile.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJson(List<StudentProfile> profiles) =>
      jsonEncode(profiles.map((p) => p.toJson()).toList());
}
