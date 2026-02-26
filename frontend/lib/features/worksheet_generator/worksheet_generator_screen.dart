import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:teacher_ai/core/api/api_service.dart';
import 'package:teacher_ai/core/components/sprout_components.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/core/utils/pdf_exporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/providers/plan_provider.dart';
import 'package:teacher_ai/core/providers/worksheet_provider.dart';
import 'package:teacher_ai/features/lesson_planner/lesson_planner_screen.dart';
import 'package:teacher_ai/features/engagement/engagement_screen.dart';
import 'package:teacher_ai/features/shell/main_shell.dart';

class WorksheetGeneratorScreen extends ConsumerStatefulWidget {
  const WorksheetGeneratorScreen({super.key});

  @override
  ConsumerState<WorksheetGeneratorScreen> createState() =>
      _WorksheetGeneratorScreenState();
}

class _WorksheetGeneratorScreenState
    extends ConsumerState<WorksheetGeneratorScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _topicController = TextEditingController();

  late final TabController _tabController;

  String _difficulty = "Medium";
  final List<String> _selectedTypes = ["MCQ"];
  bool _isLoading = false;
  String _generatedContent = "";
  int? _generatedWorksheetId;
  String _statusMessage = "";

  // Multi-plan multi-session selection: planId → Set of selected session indices (1-based)
  final Map<int, Set<int>> _selectedSessions = {};
  final Set<int> _expandedPlans = {};

  // Viewer state
  WorksheetModel? _viewingWorksheet;

  // Inline editor state
  bool _isEditingWorksheet = false;
  bool _isSavingEdit = false;
  final TextEditingController _editController = TextEditingController();

  // Per-type question count controllers
  final Map<String, TextEditingController> _typeCounts = {
    "MCQ": TextEditingController(text: '5'),
    "One Mark": TextEditingController(text: '5'),
    "Long Answer": TextEditingController(text: '3'),
  };

  final List<String> _difficultyLevels = ["Easy", "Medium", "Hard"];
  final List<String> _questionTypes = ["MCQ", "One Mark", "Long Answer"];

  String get _grade => ref.read(shellProvider).selectedGrade ?? '';
  String get _subject => ref.read(shellProvider).selectedSubject ?? '';

  int get _totalSelected =>
      _selectedSessions.values.fold(0, (sum, s) => sum + s.length);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shell = ref.read(shellProvider);
      ref.read(worksheetProvider.notifier).fetchAll(
            grade: shell.selectedGrade ?? '',
            subject: shell.selectedSubject ?? '',
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicController.dispose();
    for (final c in _typeCounts.values) {
      c.dispose();
    }
    _editController.dispose();
    super.dispose();
  }

  // ── Session helpers ───────────────────────────────────────────────────────

  List<String> _parseSessions(String content) {
    final regex = RegExp(r'##\s*(?:Session|Lecture)\s*\d+[:\s]');
    final parts = content.split(regex);
    return parts.length > 1 ? parts.sublist(1) : [];
  }

  String _sessionTitle(String content, int index) {
    final regex = RegExp(
      r'##\s*(?:Session|Lecture)\s*' + index.toString() + r'[:\s](.*)',
      multiLine: true,
    );
    final m = regex.firstMatch(content);
    if (m != null) {
      final raw = m.group(1)?.trim() ?? '';
      return raw.replaceFirst(RegExp(r'^[:\-\s]+'), '');
    }
    return 'Session $index';
  }

  String _buildCombinedSessionContext(List<LessonPlanModel> plans) {
    final buffer = StringBuffer();
    for (final plan in plans) {
      final selectedForPlan = _selectedSessions[plan.id];
      if (selectedForPlan == null || selectedForPlan.isEmpty) continue;
      final sessions = _parseSessions(plan.content);
      buffer.writeln('## Plan: ${plan.topic}');
      buffer.writeln();
      for (final idx in (selectedForPlan.toList()..sort())) {
        if (idx - 1 < sessions.length) {
          buffer.writeln('### Session $idx: ${_sessionTitle(plan.content, idx)}');
          buffer.writeln(sessions[idx - 1].trim());
          buffer.writeln();
        }
      }
    }
    return buffer.toString().trim();
  }

  String _deriveTopic(List<LessonPlanModel> plans) {
    final parts = <String>[];
    for (final plan in plans) {
      final selectedForPlan = _selectedSessions[plan.id];
      if (selectedForPlan == null || selectedForPlan.isEmpty) continue;
      final total = _parseSessions(plan.content).length;
      if (selectedForPlan.length == total) {
        parts.add(plan.topic);
      } else {
        for (final idx in (selectedForPlan.toList()..sort())) {
          parts.add(_sessionTitle(plan.content, idx));
        }
      }
    }
    return parts.join(', ');
  }

  // ── Generate ──────────────────────────────────────────────────────────────

  // Build question_counts map for selected types
  Map<String, int> get _questionCounts {
    final counts = <String, int>{};
    for (final type in _selectedTypes) {
      final raw = _typeCounts[type]?.text.trim() ?? '';
      counts[type] = int.tryParse(raw) ?? 5;
    }
    return counts;
  }

  int get _totalQuestions =>
      _questionCounts.values.fold(0, (sum, n) => sum + n);

  Future<void> _generate() async {
    final allPlans = ref.read(planProvider).plans;
    final sessionContext = _buildCombinedSessionContext(allPlans);
    String topic = _topicController.text.trim();
    if (topic.isEmpty) {
      topic = _totalSelected > 0 ? _deriveTopic(allPlans) : 'General';
    }

    final counts = _questionCounts;
    final total = _totalQuestions;

    setState(() {
      _isLoading = true;
      _generatedContent = "";
      _generatedWorksheetId = null;
      _statusMessage = _totalSelected > 0
          ? "Generating from $_totalSelected session(s)…"
          : "Designing questions…";
    });

    try {
      final res = await _apiService.generateWorksheet(
        topic: topic,
        difficulty: _difficulty,
        questionType: _selectedTypes.join(", "),
        count: total,
        questionCounts: counts,
        useRag: false,
        planId: null,
        sessionContext: sessionContext.isNotEmpty ? sessionContext : null,
        grade: _grade,
        subject: _subject,
      );
      if (res['success'] == true) {
        final content = res['content'] as String;
        final savedId = res['plan_id'] as int?;
        setState(() {
          _generatedContent = content;
          _generatedWorksheetId = savedId;
        });
        if (savedId != null) {
          final ws = WorksheetModel(
            id: savedId,
            teacherId: ApiService.teacherId,
            grade: _grade,
            subject: _subject,
            topic: topic,
            difficulty: _difficulty,
            questionType: _selectedTypes.join(", "),
            numQuestions: total,
            content: content,
            planId: null,
            createdAt: DateTime.now().toIso8601String(),
          );
          ref.read(worksheetProvider.notifier).addWorksheet(ws);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Edit helpers ──────────────────────────────────────────────────────────

  void _openEditor(String content, {WorksheetModel? ws, int? generatedId}) {
    _editController.text = content;
    setState(() => _isEditingWorksheet = true);
  }

  void _cancelEdit() {
    setState(() {
      _isEditingWorksheet = false;
      _isSavingEdit = false;
    });
  }

  Future<void> _saveEdit() async {
    final newContent = _editController.text.trim();
    if (newContent.isEmpty) return;
    setState(() => _isSavingEdit = true);
    try {
      if (_viewingWorksheet != null) {
        await ref
            .read(worksheetProvider.notifier)
            .updateContent(_viewingWorksheet!.id, newContent);
        final updated = ref
            .read(worksheetProvider)
            .worksheets
            .where((w) => w.id == _viewingWorksheet!.id)
            .firstOrNull;
        if (mounted) {
          setState(() {
            _viewingWorksheet = updated ?? _viewingWorksheet;
            _isEditingWorksheet = false;
            _isSavingEdit = false;
          });
        }
      } else if (_generatedWorksheetId != null) {
        await ref
            .read(worksheetProvider.notifier)
            .updateContent(_generatedWorksheetId!, newContent);
        if (mounted) {
          setState(() {
            _generatedContent = newContent;
            _isEditingWorksheet = false;
            _isSavingEdit = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isSavingEdit = false);
    }
  }

  // ── Rename dialog ─────────────────────────────────────────────────────────

  Future<void> _showRenameDialog(WorksheetModel ws) async {
    final controller = TextEditingController(text: ws.displayName);
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Worksheet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter worksheet name',
            prefixIcon: const Icon(Icons.drive_file_rename_outline_rounded,
                size: 18, color: AppTheme.brown),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.brown, width: 2),
            ),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          const Gap(8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.brown),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final newTitle = controller.text.trim();
      if (newTitle.isNotEmpty && newTitle != ws.displayName) {
        await ref
            .read(worksheetProvider.notifier)
            .renameWorksheet(ws.id, newTitle);
        if (_viewingWorksheet?.id == ws.id) {
          final updated = ref
              .read(worksheetProvider)
              .worksheets
              .where((w) => w.id == ws.id)
              .firstOrNull;
          if (updated != null) setState(() => _viewingWorksheet = updated);
        }
      }
    }
    controller.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shell = ref.watch(shellProvider);
    final grade = shell.selectedGrade ?? '';
    final subject = shell.selectedSubject ?? '';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: _buildAppBar(grade, subject),
      body: _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar(String grade, String subject) {
    final showTabs = _viewingWorksheet == null && !_isEditingWorksheet;

    return AppBar(
      backgroundColor: AppTheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      leadingWidth: 48,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
        tooltip: 'Back',
        onPressed: () {
          if (_isEditingWorksheet) {
            _cancelEdit();
            return;
          }
          if (_viewingWorksheet != null) {
            setState(() => _viewingWorksheet = null);
            return;
          }
          Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushReplacement(context,
                  MaterialPageRoute(
                      builder: (_) => const LessonPlannerScreen()));
        },
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isEditingWorksheet
                ? 'Edit Worksheet'
                : _viewingWorksheet != null
                    ? _viewingWorksheet!.displayName
                    : 'Worksheet Generator',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            overflow: TextOverflow.ellipsis,
          ),
          if (grade.isNotEmpty && subject.isNotEmpty)
            Text(
              '$grade · $subject',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
        ],
      ),
      actions: [
        if (_isEditingWorksheet) ...[
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: TextButton(
              onPressed: _cancelEdit,
              child: const Text('Cancel'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isSavingEdit ? null : _saveEdit,
              icon: _isSavingEdit
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_isSavingEdit ? 'Saving…' : 'Save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brown,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ),
        ] else if (_viewingWorksheet == null)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              tooltip: 'Engagement Suggestions',
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.successLight,
                foregroundColor: AppTheme.success,
              ),
              onPressed: () => Navigator.pushReplacement(context,
                  MaterialPageRoute(
                      builder: (_) => const EngagementSuggestionScreen())),
            ),
          ),
      ],
      bottom: showTabs
          ? TabBar(
              controller: _tabController,
              labelColor: AppTheme.brown,
              unselectedLabelColor: AppTheme.textSecondary,
              indicatorColor: AppTheme.brown,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.edit_note_rounded, size: 20), text: 'Create'),
                Tab(
                    icon: Icon(Icons.folder_copy_rounded, size: 20),
                    text: 'Saved'),
              ],
            )
          : PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(color: AppTheme.border, height: 1),
            ),
    );
  }

  Widget _buildBody() {
    if (_isEditingWorksheet) return _buildInlineEditor();
    if (_viewingWorksheet != null) {
      return _buildWorksheetViewer(_viewingWorksheet!);
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildCreateTab(), _buildSavedTab()],
    );
  }

  Widget _buildInlineEditor() {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: TextField(
                controller: _editController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.6,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: 'Edit worksheet content (Markdown)…',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Tab 1: Create ─────────────────────────────────────────────────────────

  Widget _buildCreateTab() {
    if (_isLoading) return _buildLoadingState();
    if (_generatedContent.isNotEmpty) return _buildOutput();
    return _buildForm();
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          const _SectionHeader(
            icon: Icons.auto_awesome_rounded,
            iconColor: AppTheme.success,
            iconBg: AppTheme.successLight,
            title: 'Create a Practice Sheet',
            subtitle: 'Select sessions or enter a custom topic',
          ),
          const Gap(20),

          // ── Plan picker ─────────────────────────────────────────────
          _buildMultiPlanPicker(),
          const Gap(20),

          // ── Topic override ───────────────────────────────────────────
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(
                    icon: Icons.topic_rounded,
                    label: 'Topic',
                    hint: 'Optional — auto-derived from selections'),
                const Gap(10),
                TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Photosynthesis, World War II…',
                  ),
                ),
              ],
            ),
          ),
          const Gap(12),

          // ── Difficulty ───────────────────────────────────────────────
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(
                    icon: Icons.signal_cellular_alt_rounded,
                    label: 'Difficulty'),
                const Gap(12),
                Row(
                  children: _difficultyLevels.map((level) {
                    final selected = _difficulty == level;
                    final color = level == 'Easy'
                        ? AppTheme.success
                        : level == 'Hard'
                            ? AppTheme.danger
                            : AppTheme.gold;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: level != _difficultyLevels.last ? 8 : 0),
                        child: GestureDetector(
                          onTap: () => setState(() => _difficulty = level),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.12)
                                  : AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    selected ? color : AppTheme.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  level == 'Easy'
                                      ? Icons.sentiment_satisfied_rounded
                                      : level == 'Hard'
                                          ? Icons.local_fire_department_rounded
                                          : Icons.sentiment_neutral_rounded,
                                  size: 20,
                                  color: selected
                                      ? color
                                      : AppTheme.textSecondary,
                                ),
                                const Gap(4),
                                Text(
                                  level,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? color
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Gap(12),

          // ── Question types ───────────────────────────────────────────
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(
                    icon: Icons.quiz_rounded, label: 'Question Types'),
                const Gap(12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _questionTypes.map((type) {
                    final selected = _selectedTypes.contains(type);
                    return GestureDetector(
                      onTap: () => setState(() {
                        selected
                            ? _selectedTypes.remove(type)
                            : _selectedTypes.add(type);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppTheme.goldSurface
                              : AppTheme.background,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppTheme.brown
                                : AppTheme.border,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.check_rounded,
                                    size: 14, color: AppTheme.brown),
                              ),
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color: selected
                                    ? AppTheme.brown
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const Gap(12),

          // ── Number of questions per type ─────────────────────────────
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(
                    icon: Icons.format_list_numbered_rounded,
                    label: 'Number of Questions'),
                const Gap(10),
                if (_selectedTypes.isEmpty)
                  const Text(
                    'Select at least one question type above.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  )
                else
                  ..._selectedTypes.map((type) {
                    final ctrl = _typeCounts[type]!;
                    final typeColor = type == 'MCQ'
                        ? AppTheme.brown
                        : type == 'One Mark'
                            ? AppTheme.success
                            : AppTheme.gold;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: typeColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Gap(8),
                          SizedBox(
                            width: 110,
                            child: Text(
                              type,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: typeColor),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: ctrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: '5',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const Gap(8),
                          // Quick picks
                          ...['3', '5', '10'].map((n) {
                            final sel = ctrl.text == n;
                            return Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => ctrl.text = n),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 120),
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: sel ? typeColor : AppTheme.background,
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(
                                      color: sel ? typeColor : AppTheme.border,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      n,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? Colors.white
                                            : AppTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                if (_selectedTypes.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.goldSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.summarize_rounded,
                            size: 14, color: AppTheme.brown),
                        const Gap(6),
                        Text(
                          'Total: $_totalQuestions questions',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.brown),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const Gap(20),

          // ── Selection summary ────────────────────────────────────────
          if (_totalSelected > 0) ...[
            _SelectionSummaryBanner(
              sessionCount: _totalSelected,
              planCount: _selectedSessions.values
                  .where((s) => s.isNotEmpty)
                  .length,
            ),
            const Gap(14),
          ],

          // ── Generate button ──────────────────────────────────────────
          ElevatedButton.icon(
            onPressed: _selectedTypes.isEmpty ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate Worksheet',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Multi-plan picker ─────────────────────────────────────────────────────

  Widget _buildMultiPlanPicker() {
    final plans = ref.watch(planProvider).plans;

    if (plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.goldSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.brown.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.brown.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.info_outline_rounded,
                  color: AppTheme.brown, size: 18),
            ),
            const Gap(12),
            const Expanded(
              child: Text(
                'No lesson plans found.\nEnter a topic manually below.',
                style: TextStyle(
                    color: AppTheme.brown,
                    fontSize: 13,
                    height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return _FormCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Row(
              children: [
                const Icon(Icons.menu_book_rounded,
                    color: AppTheme.brown, size: 18),
                const Gap(8),
                const Expanded(
                  child: Text(
                    'Select Sessions from Plans',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    if (_totalSelected > 0) {
                      _selectedSessions.clear();
                    } else {
                      for (final p in plans) {
                        final count = _parseSessions(p.content).length;
                        _selectedSessions[p.id] =
                            Set.from(List.generate(count, (i) => i + 1));
                        _expandedPlans.add(p.id);
                      }
                    }
                  }),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.brown,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _totalSelected > 0 ? 'Clear All' : 'Select All',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...plans.asMap().entries.map((e) {
            final isLast = e.key == plans.length - 1;
            return Column(
              children: [
                _buildPlanCard(e.value),
                if (!isLast) const Divider(height: 1),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPlanCard(LessonPlanModel plan) {
    final sessions = _parseSessions(plan.content);
    final selectedForPlan = _selectedSessions[plan.id] ?? {};
    final isExpanded = _expandedPlans.contains(plan.id);
    final allChecked =
        sessions.isNotEmpty && selectedForPlan.length == sessions.length;
    final someChecked =
        selectedForPlan.isNotEmpty && selectedForPlan.length < sessions.length;

    return Column(
      children: [
        // ── Plan header ────────────────────────────────────────────────
        InkWell(
          onTap: () => setState(() {
            isExpanded
                ? _expandedPlans.remove(plan.id)
                : _expandedPlans.add(plan.id);
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Tri-state checkbox
                GestureDetector(
                  onTap: () => setState(() {
                    if (allChecked) {
                      _selectedSessions.remove(plan.id);
                    } else {
                      _selectedSessions[plan.id] = Set.from(
                          List.generate(sessions.length, (i) => i + 1));
                      _expandedPlans.add(plan.id);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: allChecked
                          ? AppTheme.brown
                          : someChecked
                              ? AppTheme.goldSurface
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (allChecked || someChecked)
                            ? AppTheme.brown
                            : AppTheme.border,
                        width: 2,
                      ),
                    ),
                    child: allChecked
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : someChecked
                            ? const Icon(Icons.remove_rounded,
                                size: 14, color: AppTheme.brown)
                            : null,
                  ),
                ),
                const Gap(10),
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: selectedForPlan.isNotEmpty
                        ? AppTheme.brown.withValues(alpha: 0.12)
                        : AppTheme.goldSurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.menu_book_rounded,
                      color: selectedForPlan.isNotEmpty
                          ? AppTheme.brown
                          : AppTheme.brown.withValues(alpha: 0.6),
                      size: 15),
                ),
                const Gap(10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.topic,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${sessions.length} session(s)'
                        '${selectedForPlan.isNotEmpty ? ' · ${selectedForPlan.length} selected' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: selectedForPlan.isNotEmpty
                              ? AppTheme.brown
                              : AppTheme.textHint,
                          fontWeight: selectedForPlan.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ),
              ],
            ),
          ),
        ),

        // ── Session list ───────────────────────────────────────────────
        if (isExpanded && sessions.isNotEmpty)
          Container(
            color: AppTheme.background,
            child: Column(
              children: List.generate(sessions.length, (i) {
                final idx = i + 1;
                final isChecked = selectedForPlan.contains(idx);
                final title = _sessionTitle(plan.content, idx);
                return Column(
                  children: [
                    const Divider(height: 1),
                    InkWell(
                      onTap: () => setState(() {
                        final set =
                            _selectedSessions.putIfAbsent(plan.id, () => {});
                        if (isChecked) {
                          set.remove(idx);
                          if (set.isEmpty) _selectedSessions.remove(plan.id);
                        } else {
                          set.add(idx);
                        }
                      }),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(52, 10, 16, 10),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? AppTheme.brown
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isChecked
                                      ? AppTheme.brown
                                      : AppTheme.border,
                                  width: 1.5,
                                ),
                              ),
                              child: isChecked
                                  ? const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                            const Gap(10),
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? AppTheme.brown
                                    : AppTheme.surface,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: isChecked
                                      ? AppTheme.brown
                                      : AppTheme.border,
                                ),
                              ),
                              child: Center(
                                child: Text('$idx',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isChecked
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                    )),
                              ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isChecked
                                      ? AppTheme.textPrimary
                                      : AppTheme.textSecondary,
                                  fontWeight: isChecked
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
      ],
    );
  }

  // ── Loading state ─────────────────────────────────────────────────────────

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppTheme.successLight,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: AppTheme.success),
              ),
            ),
            const Gap(24),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600),
            ),
            const Gap(8),
            const Text(
              'This may take a few seconds…',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  // ── Generated output ──────────────────────────────────────────────────────

  Widget _buildOutput() {
    final safeFileName = _topicController.text
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: _generatedContent,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h1: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.brown),
                  h2: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                  p: const TextStyle(height: 1.6, fontSize: 14),
                  listBullet: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
        _buildOutputActionBar(safeFileName),
      ],
    );
  }

  Widget _buildOutputActionBar(String safeFileName) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: const Border(top: BorderSide(color: AppTheme.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  onPressed: () => setState(() => _generatedContent = ""),
                  label: const Text('Redo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  onPressed: () => _openEditor(_generatedContent, generatedId: _generatedWorksheetId),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.success,
                    side: const BorderSide(color: AppTheme.success),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  onPressed: _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  label: const Text('Regenerate'),
                ),
              ),
            ],
          ),
          const Gap(10),
          _ExportPdfButton(
            tooltip: 'Download worksheet as PDF',
            label: 'Export PDF',
            onExport: () => exportMarkdownToPdf(
              markdownContent: _generatedContent,
              fileName:
                  safeFileName.isNotEmpty ? 'Worksheet_$safeFileName' : 'Worksheet',
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Saved Worksheets ───────────────────────────────────────────────

  Widget _buildSavedTab() {
    final wsState = ref.watch(worksheetProvider);

    if (wsState.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.brown),
      );
    }

    if (wsState.worksheets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.folder_open_rounded,
                    size: 36, color: AppTheme.textHint),
              ),
              const Gap(20),
              const Text(
                'No worksheets yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const Gap(6),
              const Text(
                'Switch to Create to generate\nyour first worksheet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5),
              ),
              const Gap(24),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create Worksheet'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _tabController.animateTo(0),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: wsState.worksheets.length,
      separatorBuilder: (_, __) => const Gap(10),
      itemBuilder: (context, index) {
        final ws = wsState.worksheets[index];
        return _WorksheetTile(
          worksheet: ws,
          onOpen: () => setState(() {
            _viewingWorksheet = ws;
          }),
          onEdit: () {
            setState(() => _viewingWorksheet = ws);
            _openEditor(ws.content, ws: ws);
          },
          onDelete: () => _confirmDelete(ws),
        );
      },
    );
  }

  // ── Saved worksheet viewer ────────────────────────────────────────────────

  Widget _buildWorksheetViewer(WorksheetModel ws) {
    return Column(
      children: [
        // Header toolbar
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: () => setState(() => _viewingWorksheet = null),
                tooltip: 'Back',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ws.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        _DifficultyBadge(difficulty: ws.difficulty),
                        const Gap(6),
                        Text(
                          '${ws.numQuestions} Qs · ${ws.questionType}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Action buttons
              _ViewerIconButton(
                icon: Icons.drive_file_rename_outline_rounded,
                color: AppTheme.brown,
                tooltip: 'Rename',
                onTap: () => _showRenameDialog(ws),
              ),
              _ViewerIconButton(
                icon: Icons.edit_rounded,
                color: AppTheme.success,
                tooltip: 'Edit',
                onTap: () => _openEditor(ws.content, ws: ws),
              ),
              _ExportPdfButton(
                tooltip: 'Export as PDF',
                onExport: () {
                  final safe = ws.displayName
                      .replaceAll(RegExp(r'[^\w\s-]'), '')
                      .trim()
                      .replaceAll(' ', '_');
                  return exportMarkdownToPdf(
                    markdownContent: ws.content,
                    fileName: 'Worksheet_$safe',
                  );
                },
              ),
              _ViewerIconButton(
                icon: Icons.delete_outline_rounded,
                color: AppTheme.danger,
                tooltip: 'Delete',
                onTap: () => _confirmDelete(ws),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: MarkdownBody(
                data: ws.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h1: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.brown),
                  h2: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textPrimary),
                  p: const TextStyle(height: 1.6, fontSize: 14),
                  listBullet: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Delete confirm ────────────────────────────────────────────────────────

  void _confirmDelete(WorksheetModel ws) {
    showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Worksheet?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: Text(
          'Remove "${ws.displayName}"? This cannot be undone.',
          style: const TextStyle(
              fontSize: 14, color: AppTheme.textSecondary, height: 1.4),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          const Gap(8),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(worksheetProvider.notifier).deleteWorksheet(ws.id);
              if (_viewingWorksheet?.id == ws.id) {
                setState(() => _viewingWorksheet = null);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Worksheet Editor Screen (full-screen route) ───────────────────────────────

class _WorksheetEditorScreen extends StatefulWidget {
  final String initialContent;
  final Future<void> Function(String newContent) onSave;

  const _WorksheetEditorScreen({
    required this.initialContent,
    required this.onSave,
  });

  @override
  State<_WorksheetEditorScreen> createState() => _WorksheetEditorScreenState();
}

class _WorksheetEditorScreenState extends State<_WorksheetEditorScreen> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newContent = _ctrl.text.trim();
    if (newContent.isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(newContent);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, size: 20),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Edit Worksheet',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(_saving ? 'Saving…' : 'Save'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.brown,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppTheme.border, height: 1)),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.goldSurface,
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 14, color: AppTheme.brown),
                Gap(8),
                Expanded(
                  child: Text(
                    'Edit the Markdown below. Tap Save when done.',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.brown),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 13, height: 1.6),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppTheme.brown, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable components ───────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _FormCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.textPrimary),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;

  const _FieldLabel({required this.icon, required this.label, this.hint});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.brown),
        const Gap(6),
        Text(
          label,
          style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: AppTheme.textPrimary),
        ),
        if (hint != null) ...[
          const Gap(6),
          Flexible(
            child: Text(
              hint!,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textHint),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class _SelectionSummaryBanner extends StatelessWidget {
  final int sessionCount;
  final int planCount;

  const _SelectionSummaryBanner(
      {required this.sessionCount, required this.planCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.success.withValues(alpha: 0.08),
            AppTheme.brown.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              size: 16, color: AppTheme.success),
          const Gap(8),
          Expanded(
            child: Text(
              '$sessionCount session${sessionCount != 1 ? 's' : ''} selected'
              ' across $planCount plan${planCount != 1 ? 's' : ''}',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.success,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ViewerIconButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ── Worksheet list tile ───────────────────────────────────────────────────────

class _WorksheetTile extends StatelessWidget {
  final WorksheetModel worksheet;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WorksheetTile({
    required this.worksheet,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.assignment_rounded,
                    color: AppTheme.success, size: 20),
              ),
              const Gap(12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worksheet.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Row(
                      children: [
                        _DifficultyBadge(difficulty: worksheet.difficulty),
                        const Gap(6),
                        Flexible(
                          child: Text(
                            '${worksheet.numQuestions} Qs · ${worksheet.questionType}',
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Gap(2),
                    Text(
                      _formatDate(worksheet.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint),
                    ),
                  ],
                ),
              ),
              // Actions
              IconButton(
                icon: const Icon(
                    Icons.edit_rounded,
                    size: 18,
                    color: AppTheme.brown),
                tooltip: 'Edit',
                onPressed: onEdit,
                style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 18, color: AppTheme.danger),
                tooltip: 'Delete',
                onPressed: onDelete,
                style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day}/${dt.month}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }
}

// ── Difficulty badge ──────────────────────────────────────────────────────────

class _DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const _DifficultyBadge({required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final color = switch (difficulty.toLowerCase()) {
      'easy' => AppTheme.success,
      'hard' => AppTheme.danger,
      _ => AppTheme.gold,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2),
      ),
    );
  }
}

// ── Export PDF button ─────────────────────────────────────────────────────────

class _ExportPdfButton extends StatefulWidget {
  final Future<void> Function() onExport;
  final String tooltip;
  final String? label;

  const _ExportPdfButton({
    required this.onExport,
    required this.tooltip,
    this.label,
  });

  @override
  State<_ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<_ExportPdfButton> {
  bool _exporting = false;

  Future<void> _run() async {
    setState(() => _exporting = true);
    try {
      await widget.onExport();
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.label != null) {
      // Full-width labelled button
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _exporting ? null : _run,
          icon: _exporting
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppTheme.gold),
                )
              : const Icon(Icons.picture_as_pdf_rounded, size: 17),
          label: Text(_exporting ? 'Exporting…' : widget.label!),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.gold,
            side: BorderSide(color: AppTheme.gold.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }
    // Icon-only variant
    if (_exporting) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.gold),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.picture_as_pdf_rounded,
          size: 18, color: AppTheme.gold),
      tooltip: widget.tooltip,
      onPressed: _run,
      style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    );
  }
}
