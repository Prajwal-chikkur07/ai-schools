import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _gradesKey = 'custom_grades';
const _subjectsKey = 'custom_subjects';

const List<String> _defaultGrades = [
  'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5',
  'Grade 6', 'Grade 7', 'Grade 8', 'Grade 9', 'Grade 10',
];

/// Sorts grades numerically: "Grade 2" < "Grade 10". Non-numeric grades go last alphabetically.
List<String> _sortedGrades(List<String> grades) {
  final copy = List<String>.from(grades);
  copy.sort((a, b) {
    final na = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
    final nb = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.compareTo(b);
  });
  return copy;
}

const List<String> _defaultSubjects = [
  'Math', 'Science', 'English', 'History',
  'Geography', 'Physics', 'Chemistry', 'Biology',
];

class GradeSubjectState {
  final List<String> grades;
  final List<String> subjects;

  const GradeSubjectState({
    required this.grades,
    required this.subjects,
  });

  GradeSubjectState copyWith({List<String>? grades, List<String>? subjects}) {
    return GradeSubjectState(
      grades: grades ?? this.grades,
      subjects: subjects ?? this.subjects,
    );
  }
}

class GradeSubjectNotifier extends StateNotifier<GradeSubjectState> {
  GradeSubjectNotifier()
      : super(const GradeSubjectState(
          grades: _defaultGrades,
          subjects: _defaultSubjects,
        )) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final gradesJson = prefs.getString(_gradesKey);
    final subjectsJson = prefs.getString(_subjectsKey);

    final grades = _sortedGrades(gradesJson != null
        ? List<String>.from(json.decode(gradesJson) as List)
        : _defaultGrades);
    final subjects = subjectsJson != null
        ? List<String>.from(json.decode(subjectsJson) as List)
        : _defaultSubjects;

    state = GradeSubjectState(grades: grades, subjects: subjects);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_gradesKey, json.encode(state.grades));
    await prefs.setString(_subjectsKey, json.encode(state.subjects));
  }

  // ── Grades ──────────────────────────────────────────────────────────────

  Future<void> addGrade(String grade) async {
    final trimmed = grade.trim();
    if (trimmed.isEmpty || state.grades.contains(trimmed)) return;
    state = state.copyWith(grades: _sortedGrades([...state.grades, trimmed]));
    await _save();
  }

  Future<void> removeGrade(String grade) async {
    state = state.copyWith(
      grades: state.grades.where((g) => g != grade).toList(),
    );
    await _save();
  }

  Future<void> resetGrades() async {
    state = state.copyWith(grades: _sortedGrades(List.from(_defaultGrades)));
    await _save();
  }

  // ── Subjects ─────────────────────────────────────────────────────────────

  Future<void> addSubject(String subject) async {
    final trimmed = subject.trim();
    if (trimmed.isEmpty || state.subjects.contains(trimmed)) return;
    state = state.copyWith(subjects: [...state.subjects, trimmed]);
    await _save();
  }

  Future<void> removeSubject(String subject) async {
    state = state.copyWith(
      subjects: state.subjects.where((s) => s != subject).toList(),
    );
    await _save();
  }

  Future<void> resetSubjects() async {
    state = state.copyWith(subjects: List.from(_defaultSubjects));
    await _save();
  }
}

final gradeSubjectProvider =
    StateNotifierProvider<GradeSubjectNotifier, GradeSubjectState>(
  (ref) => GradeSubjectNotifier(),
);
