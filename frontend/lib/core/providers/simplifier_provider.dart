import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/api/api_service.dart';

class SimplifierModel {
  final int id;
  final String teacherId;
  final String grade;
  final String subject;
  final String? title;
  final String topic;
  final String content;
  final int? planId;
  final String createdAt;

  const SimplifierModel({
    required this.id,
    required this.teacherId,
    required this.grade,
    required this.subject,
    this.title,
    required this.topic,
    required this.content,
    this.planId,
    required this.createdAt,
  });

  String get displayName =>
      (title != null && title!.trim().isNotEmpty) ? title! : topic;

  factory SimplifierModel.fromMap(Map<String, dynamic> m) => SimplifierModel(
        id: m['id'],
        teacherId: m['teacher_id'],
        grade: m['grade'] ?? '',
        subject: m['subject'] ?? '',
        title: m['title'],
        topic: m['topic'],
        content: m['content'],
        planId: m['plan_id'],
        createdAt: m['created_at'] ?? '',
      );

  SimplifierModel copyWith({String? content, String? title}) => SimplifierModel(
        id: id,
        teacherId: teacherId,
        grade: grade,
        subject: subject,
        title: title ?? this.title,
        topic: topic,
        content: content ?? this.content,
        planId: planId,
        createdAt: createdAt,
      );
}

class SimplifierState {
  final List<SimplifierModel> results;
  final bool isLoading;

  const SimplifierState({this.results = const [], this.isLoading = false});

  SimplifierState copyWith({List<SimplifierModel>? results, bool? isLoading}) =>
      SimplifierState(
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
      );
}

class SimplifierNotifier extends StateNotifier<SimplifierState> {
  final _api = ApiService();

  SimplifierNotifier() : super(const SimplifierState());

  Future<void> fetchAll({String grade = '', String subject = ''}) async {
    state = const SimplifierState(isLoading: true);
    try {
      final raw = await _api.fetchSimplifierResults(grade: grade, subject: subject);
      state = SimplifierState(
        results: raw.map(SimplifierModel.fromMap).toList(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void addResult(SimplifierModel result) {
    state = state.copyWith(
      results: [result, ...state.results.where((r) => r.id != result.id)],
    );
  }

  Future<void> updateContent(int id, String newContent) async {
    await _api.updateSimplifierResult(id, content: newContent);
    state = state.copyWith(
      results: state.results
          .map((r) => r.id == id ? r.copyWith(content: newContent) : r)
          .toList(),
    );
  }

  Future<void> renameResult(int id, String newTitle) async {
    await _api.updateSimplifierResult(id, title: newTitle);
    state = state.copyWith(
      results: state.results
          .map((r) => r.id == id ? r.copyWith(title: newTitle) : r)
          .toList(),
    );
  }

  Future<void> deleteResult(int id) async {
    await _api.deleteSimplifierResult(id);
    state = state.copyWith(
      results: state.results.where((r) => r.id != id).toList(),
    );
  }
}

final simplifierProvider =
    StateNotifierProvider<SimplifierNotifier, SimplifierState>(
  (ref) => SimplifierNotifier(),
);
