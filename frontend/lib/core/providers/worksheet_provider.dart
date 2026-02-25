import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/api/api_service.dart';

/// Represents a single saved worksheet.
class WorksheetModel {
  final int id;
  final String teacherId;
  final String grade;
  final String subject;
  final String? title;   // user-editable display name (null = use topic)
  final String topic;
  final String difficulty;
  final String questionType;
  final int numQuestions;
  final String content;
  final int? planId;
  final String createdAt;

  const WorksheetModel({
    required this.id,
    required this.teacherId,
    required this.grade,
    required this.subject,
    this.title,
    required this.topic,
    required this.difficulty,
    required this.questionType,
    required this.numQuestions,
    required this.content,
    this.planId,
    required this.createdAt,
  });

  /// The display name shown in the list — title if set, otherwise topic.
  String get displayName => (title != null && title!.trim().isNotEmpty) ? title! : topic;

  factory WorksheetModel.fromMap(Map<String, dynamic> m) => WorksheetModel(
        id: m['id'],
        teacherId: m['teacher_id'],
        grade: m['grade'] ?? '',
        subject: m['subject'] ?? '',
        title: m['title'],
        topic: m['topic'],
        difficulty: m['difficulty'],
        questionType: m['question_type'],
        numQuestions: m['num_questions'],
        content: m['content'],
        planId: m['plan_id'],
        createdAt: m['created_at'] ?? '',
      );

  WorksheetModel copyWith({String? content, String? title}) => WorksheetModel(
        id: id,
        teacherId: teacherId,
        grade: grade,
        subject: subject,
        title: title ?? this.title,
        topic: topic,
        difficulty: difficulty,
        questionType: questionType,
        numQuestions: numQuestions,
        content: content ?? this.content,
        planId: planId,
        createdAt: createdAt,
      );
}

class WorksheetState {
  final List<WorksheetModel> worksheets;
  final bool isLoading;

  const WorksheetState({this.worksheets = const [], this.isLoading = false});

  WorksheetState copyWith(
          {List<WorksheetModel>? worksheets, bool? isLoading}) =>
      WorksheetState(
        worksheets: worksheets ?? this.worksheets,
        isLoading: isLoading ?? this.isLoading,
      );
}

class WorksheetNotifier extends StateNotifier<WorksheetState> {
  final _api = ApiService();

  WorksheetNotifier() : super(const WorksheetState());

  /// Fetch worksheets scoped to the current grade + subject.
  Future<void> fetchAll({String grade = '', String subject = ''}) async {
    state = const WorksheetState(isLoading: true);
    try {
      final raw = await _api.fetchWorksheets(grade: grade, subject: subject);
      state = WorksheetState(
        worksheets: raw.map(WorksheetModel.fromMap).toList(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  /// Prepend a just-generated worksheet to the list without a full refetch.
  void addWorksheet(WorksheetModel ws) {
    state = state.copyWith(
      worksheets: [ws, ...state.worksheets.where((w) => w.id != ws.id)],
    );
  }

  /// Update content locally and persist to backend.
  Future<void> updateContent(int id, String newContent) async {
    await _api.updateWorksheet(id, content: newContent);
    state = state.copyWith(
      worksheets: state.worksheets
          .map((w) => w.id == id ? w.copyWith(content: newContent) : w)
          .toList(),
    );
  }

  /// Rename (update title) locally and persist to backend.
  Future<void> renameWorksheet(int id, String newTitle) async {
    await _api.updateWorksheet(id, title: newTitle);
    state = state.copyWith(
      worksheets: state.worksheets
          .map((w) => w.id == id ? w.copyWith(title: newTitle) : w)
          .toList(),
    );
  }

  Future<void> deleteWorksheet(int id) async {
    await _api.deleteWorksheet(id);
    state = state.copyWith(
      worksheets: state.worksheets.where((w) => w.id != id).toList(),
    );
  }
}

final worksheetProvider =
    StateNotifierProvider<WorksheetNotifier, WorksheetState>(
  (ref) => WorksheetNotifier(),
);
