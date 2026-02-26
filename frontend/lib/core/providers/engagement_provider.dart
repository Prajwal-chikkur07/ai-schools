import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/api/api_service.dart';

class EngagementModel {
  final int id;
  final String teacherId;
  final String grade;
  final String subject;
  final String? title;
  final String topic;
  final String engagementType;
  final String content;
  final int? planId;
  final String createdAt;

  const EngagementModel({
    required this.id,
    required this.teacherId,
    required this.grade,
    required this.subject,
    this.title,
    required this.topic,
    required this.engagementType,
    required this.content,
    this.planId,
    required this.createdAt,
  });

  String get displayName =>
      (title != null && title!.trim().isNotEmpty) ? title! : '$engagementType — $topic';

  factory EngagementModel.fromMap(Map<String, dynamic> m) => EngagementModel(
        id: m['id'],
        teacherId: m['teacher_id'],
        grade: m['grade'] ?? '',
        subject: m['subject'] ?? '',
        title: m['title'],
        topic: m['topic'],
        engagementType: m['engagement_type'],
        content: m['content'],
        planId: m['plan_id'],
        createdAt: m['created_at'] ?? '',
      );

  EngagementModel copyWith({String? content, String? title}) => EngagementModel(
        id: id,
        teacherId: teacherId,
        grade: grade,
        subject: subject,
        title: title ?? this.title,
        topic: topic,
        engagementType: engagementType,
        content: content ?? this.content,
        planId: planId,
        createdAt: createdAt,
      );
}

class EngagementState {
  final List<EngagementModel> engagements;
  final bool isLoading;

  const EngagementState({this.engagements = const [], this.isLoading = false});

  EngagementState copyWith({List<EngagementModel>? engagements, bool? isLoading}) =>
      EngagementState(
        engagements: engagements ?? this.engagements,
        isLoading: isLoading ?? this.isLoading,
      );
}

class EngagementNotifier extends StateNotifier<EngagementState> {
  final _api = ApiService();

  EngagementNotifier() : super(const EngagementState());

  Future<void> fetchAll({String grade = '', String subject = ''}) async {
    state = const EngagementState(isLoading: true);
    try {
      final raw = await _api.fetchEngagements(grade: grade, subject: subject);
      state = EngagementState(
        engagements: raw.map(EngagementModel.fromMap).toList(),
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  void addEngagement(EngagementModel eng) {
    state = state.copyWith(
      engagements: [eng, ...state.engagements.where((e) => e.id != eng.id)],
    );
  }

  Future<void> updateContent(int id, String newContent) async {
    await _api.updateEngagement(id, content: newContent);
    state = state.copyWith(
      engagements: state.engagements
          .map((e) => e.id == id ? e.copyWith(content: newContent) : e)
          .toList(),
    );
  }

  Future<void> renameEngagement(int id, String newTitle) async {
    await _api.updateEngagement(id, title: newTitle);
    state = state.copyWith(
      engagements: state.engagements
          .map((e) => e.id == id ? e.copyWith(title: newTitle) : e)
          .toList(),
    );
  }

  Future<void> deleteEngagement(int id) async {
    await _api.deleteEngagement(id);
    state = state.copyWith(
      engagements: state.engagements.where((e) => e.id != id).toList(),
    );
  }
}

final engagementProvider =
    StateNotifierProvider<EngagementNotifier, EngagementState>(
  (ref) => EngagementNotifier(),
);
