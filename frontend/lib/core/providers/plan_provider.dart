import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/api/api_service.dart';

/// Model representing a single stored lesson plan
class LessonPlanModel {
  final int id;
  final String teacherId;
  final String grade;
  final String subject;
  final String topic;
  final int numLectures;
  String content; // mutable for in-memory edits
  final String createdAt;

  LessonPlanModel({
    required this.id,
    required this.teacherId,
    required this.grade,
    required this.subject,
    required this.topic,
    required this.numLectures,
    required this.content,
    required this.createdAt,
  });

  factory LessonPlanModel.fromMap(Map<String, dynamic> map) {
    return LessonPlanModel(
      id: map['id'],
      teacherId: map['teacher_id'],
      grade: map['grade'],
      subject: map['subject'],
      topic: map['topic'],
      numLectures: map['num_lectures'],
      content: map['content'],
      createdAt: map['created_at'] ?? '',
    );
  }
}

/// State: plans for the currently selected grade+subject, plus which one is open
class PlanListState {
  final List<LessonPlanModel> plans;
  final int? activePlanId;
  final bool isLoading;

  const PlanListState({
    this.plans = const [],
    this.activePlanId,
    this.isLoading = false,
  });

  PlanListState copyWith({
    List<LessonPlanModel>? plans,
    int? activePlanId,
    bool? isLoading,
    bool clearActive = false,
  }) {
    return PlanListState(
      plans: plans ?? this.plans,
      activePlanId: clearActive ? null : (activePlanId ?? this.activePlanId),
      isLoading: isLoading ?? this.isLoading,
    );
  }

  LessonPlanModel? get activePlan =>
      activePlanId != null
          ? plans.where((p) => p.id == activePlanId).firstOrNull
          : null;

  String? get topic => activePlan?.topic;
  String? get originalLessonPlan => activePlan?.content;
}

class PlanListNotifier extends StateNotifier<PlanListState> {
  final _api = ApiService();

  PlanListNotifier() : super(const PlanListState());

  /// Fetch plans for a specific grade+subject only.
  /// Clears the current list before loading so stale plans never linger.
  Future<void> fetchPlans({required String grade, required String subject}) async {
    // Clear immediately so the UI never shows plans from a previous grade/subject
    final previousActiveId = state.activePlanId;
    state = const PlanListState(isLoading: true);
    try {
      final raw = await _api.fetchPlans(grade: grade, subject: subject);
      final plans = raw.map(LessonPlanModel.fromMap).toList();
      // Restore the previously active plan if it still exists in the new list
      final restoredActiveId = plans.any((p) => p.id == previousActiveId)
          ? previousActiveId
          : (plans.isNotEmpty ? plans.first.id : null);
      state = PlanListState(plans: plans, activePlanId: restoredActiveId, isLoading: false);
    } catch (_) {
      state = const PlanListState(isLoading: false);
    }
  }

  void setActivePlan(int id) {
    state = state.copyWith(activePlanId: id);
  }

  void clearActivePlan() {
    state = state.copyWith(clearActive: true);
  }

  /// Called by LessonPlannerScreen after a successful generation.
  /// Prepends the new plan (deduplicating) and does NOT auto-activate it —
  /// the dashboard auto-selects based on context.
  void addNewPlan(LessonPlanModel plan) {
    final updated = [plan, ...state.plans.where((p) => p.id != plan.id)];
    state = state.copyWith(plans: updated);
  }

  /// Update content locally + persist to backend
  Future<void> updatePlanContent(int planId, String newContent) async {
    final updated = state.plans.map((p) {
      if (p.id == planId) {
        return LessonPlanModel(
          id: p.id,
          teacherId: p.teacherId,
          grade: p.grade,
          subject: p.subject,
          topic: p.topic,
          numLectures: p.numLectures,
          content: newContent,
          createdAt: p.createdAt,
        );
      }
      return p;
    }).toList();
    state = state.copyWith(plans: updated);
    await _api.updatePlan(planId, newContent);
  }

  /// Delete a plan from backend and remove from local list
  Future<void> deletePlan(int planId) async {
    await _api.deletePlan(planId);
    final updated = state.plans.where((p) => p.id != planId).toList();
    final newActive = state.activePlanId == planId ? null : state.activePlanId;
    state = PlanListState(plans: updated, activePlanId: newActive);
  }

  void clear() => clearActivePlan();
}

final planProvider = StateNotifierProvider<PlanListNotifier, PlanListState>((ref) {
  return PlanListNotifier();
});
