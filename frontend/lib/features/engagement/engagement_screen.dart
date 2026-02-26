import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:teacher_ai/core/api/api_service.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/core/utils/pdf_exporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/providers/plan_provider.dart';
import 'package:teacher_ai/core/providers/engagement_provider.dart';
import 'package:teacher_ai/features/worksheet_generator/worksheet_generator_screen.dart';
import 'package:teacher_ai/features/concept_simplifier/concept_simplifier_screen.dart';
import 'package:teacher_ai/features/shell/main_shell.dart';

class EngagementSuggestionScreen extends ConsumerStatefulWidget {
  const EngagementSuggestionScreen({super.key});

  @override
  ConsumerState<EngagementSuggestionScreen> createState() =>
      _EngagementSuggestionScreenState();
}

class _EngagementSuggestionScreenState
    extends ConsumerState<EngagementSuggestionScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _topicController = TextEditingController();

  late final TabController _tabController;

  String _selectedType = 'Icebreaker';
  int _numQuestions = 5;
  String _activityFormat = 'Group Activity';
  String _discussionFormat = 'Think-Pair-Share';
  bool _isLoading = false;
  String _statusMessage = '';
  String _generatedContent = '';
  int? _generatedId;

  // Plan/session selection (same pattern as worksheet generator)
  final Map<int, Set<int>> _selectedSessions = {};
  final Set<int> _expandedPlans = {};

  // History viewer state
  EngagementModel? _viewingEngagement;

  // Edit state
  bool _isEditing = false;
  bool _isSavingEdit = false;
  final TextEditingController _editController = TextEditingController();

  // Rename state
  final TextEditingController _renameTitleController = TextEditingController();

  static const List<Map<String, dynamic>> _types = [
    {'name': 'Icebreaker', 'icon': Icons.waving_hand_outlined},
    {'name': 'Quiz', 'icon': Icons.quiz_outlined},
    {'name': 'Activities', 'icon': Icons.sports_esports_outlined},
    {'name': 'Discussion', 'icon': Icons.forum_outlined},
  ];

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
      ref.read(engagementProvider.notifier).fetchAll(
            grade: shell.selectedGrade ?? '',
            subject: shell.selectedSubject ?? '',
          );
      // Expand all plans by default
      for (final plan in ref.read(planProvider).plans) {
        _expandedPlans.add(plan.id);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _topicController.dispose();
    _editController.dispose();
    _renameTitleController.dispose();
    super.dispose();
  }

  // ── Session helpers (same as worksheet generator) ─────────────────────────

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
          buffer.writeln(
              '### Session $idx: ${_sessionTitle(plan.content, idx)}');
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

  Future<void> _generate() async {
    final allPlans = ref.read(planProvider).plans;
    final sessionContext = _buildCombinedSessionContext(allPlans);
    String topic = _topicController.text.trim();
    if (topic.isEmpty) {
      topic = _totalSelected > 0 ? _deriveTopic(allPlans) : 'General';
    }

    setState(() {
      _isLoading = true;
      _generatedContent = '';
      _generatedId = null;
      _statusMessage = _totalSelected > 0
          ? 'Creating from $_totalSelected session(s)…'
          : 'Generating ${_selectedType.toLowerCase()} ideas…';
    });

    try {
      final res = await _apiService.generateEngagement(
        topic: topic,
        type: _selectedType,
        planId: null,
        grade: _grade,
        subject: _subject,
        sessionContext: sessionContext.isNotEmpty ? sessionContext : null,
        numQuestions: _selectedType == 'Quiz' ? _numQuestions : null,
        activityFormat: _selectedType == 'Activities' ? _activityFormat : null,
        discussionFormat:
            _selectedType == 'Discussion' ? _discussionFormat : null,
      );
      if (res['success'] == true) {
        final content = res['content'] as String;
        final savedId = res['plan_id'] as int?;
        setState(() {
          _generatedContent = content;
          _generatedId = savedId;
        });
        if (savedId != null) {
          final eng = EngagementModel(
            id: savedId,
            teacherId: ApiService.teacherId,
            grade: _grade,
            subject: _subject,
            topic: topic,
            engagementType: _selectedType,
            content: content,
            planId: null,
            createdAt: DateTime.now().toIso8601String(),
          );
          ref.read(engagementProvider.notifier).addEngagement(eng);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Edit helpers ──────────────────────────────────────────────────────────

  void _openEditor(String content) {
    _editController.text = content;
    setState(() => _isEditing = true);
  }

  void _cancelEdit() => setState(() {
        _isEditing = false;
        _isSavingEdit = false;
      });

  Future<void> _saveEdit() async {
    final newContent = _editController.text.trim();
    if (newContent.isEmpty) return;
    setState(() => _isSavingEdit = true);
    try {
      if (_viewingEngagement != null) {
        await ref
            .read(engagementProvider.notifier)
            .updateContent(_viewingEngagement!.id, newContent);
        final updated = ref
            .read(engagementProvider)
            .engagements
            .where((e) => e.id == _viewingEngagement!.id)
            .firstOrNull;
        setState(() {
          _viewingEngagement =
              updated ?? _viewingEngagement!.copyWith(content: newContent);
          _isEditing = false;
        });
      } else if (_generatedId != null) {
        await ref
            .read(engagementProvider.notifier)
            .updateContent(_generatedId!, newContent);
        setState(() {
          _generatedContent = newContent;
          _isEditing = false;
        });
      }
    } finally {
      setState(() => _isSavingEdit = false);
    }
  }

  // ── Regenerate bottom sheet ────────────────────────────────────────────────

  void _showRegenSheet({required String currentContent, required int? engId}) {
    final instrCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Regenerate with Instructions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(12),
            TextField(
              controller: instrCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'e.g. Make it more fun, add collaborative elements…',
                border: OutlineInputBorder(),
              ),
            ),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
                const Gap(12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600),
                    onPressed: () async {
                      final instr = instrCtrl.text.trim();
                      if (instr.isEmpty) return;
                      Navigator.pop(ctx);
                      await _regenerateWithInstruction(
                          currentContent, instr, engId);
                    },
                    child: const Text('Regenerate'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _regenerateWithInstruction(
      String original, String instruction, int? engId) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Regenerating…';
    });
    try {
      final res = await _apiService.regenerate(
        feature: 'engagement',
        originalContent: original,
        instruction: instruction,
        planId: null,
      );
      if (res['success'] == true) {
        final newContent = res['content'] as String;
        if (engId != null) {
          await ref
              .read(engagementProvider.notifier)
              .updateContent(engId, newContent);
          if (_viewingEngagement != null && _viewingEngagement!.id == engId) {
            final updated = ref
                .read(engagementProvider)
                .engagements
                .where((e) => e.id == engId)
                .firstOrNull;
            setState(() {
              _viewingEngagement =
                  updated ?? _viewingEngagement!.copyWith(content: newContent);
            });
          } else {
            setState(() => _generatedContent = newContent);
          }
        } else {
          setState(() => _generatedContent = newContent);
        }
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Rename dialog ─────────────────────────────────────────────────────────

  void _showRenameDialog(EngagementModel eng) {
    _renameTitleController.text = eng.title ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: TextField(
          controller: _renameTitleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter a title…'),
          onSubmitted: (_) => _doRename(ctx, eng),
        ),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          const Gap(8),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.orange.shade600),
            onPressed: () => _doRename(ctx, eng),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _doRename(BuildContext ctx, EngagementModel eng) async {
    final title = _renameTitleController.text.trim();
    Navigator.pop(ctx);
    if (title.isEmpty) return;
    await ref
        .read(engagementProvider.notifier)
        .renameEngagement(eng.id, title);
    if (_viewingEngagement?.id == eng.id) {
      final updated = ref
          .read(engagementProvider)
          .engagements
          .where((e) => e.id == eng.id)
          .firstOrNull;
      setState(() {
        _viewingEngagement = updated ?? eng.copyWith(title: title);
      });
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteEngagement(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Engagement?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(engagementProvider.notifier).deleteEngagement(id);
      if (_viewingEngagement?.id == id) {
        setState(() {
          _viewingEngagement = null;
          _isEditing = false;
        });
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final shell = ref.watch(shellProvider);
    final grade = shell.selectedGrade ?? '';
    final subject = shell.selectedSubject ?? '';
    final showTabs =
        _viewingEngagement == null && !_isEditing && !_isLoading;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          tooltip: 'Back',
          onPressed: () {
            if (_isEditing) {
              _cancelEdit();
              return;
            }
            if (_viewingEngagement != null) {
              setState(() => _viewingEngagement = null);
              return;
            }
            if (_generatedContent.isNotEmpty) {
              setState(() {
                _generatedContent = '';
                _generatedId = null;
              });
              return;
            }
            Navigator.canPop(context)
                ? Navigator.pop(context)
                : Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const WorksheetGeneratorScreen()));
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing
                  ? 'Edit Engagement'
                  : _viewingEngagement != null
                      ? _viewingEngagement!.displayName
                      : 'Engagement Suggestions',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            if (grade.isNotEmpty && subject.isNotEmpty)
              Text(
                '$grade · $subject',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
          ],
        ),
        actions: [
          if (_isEditing) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child:
                  TextButton(onPressed: _cancelEdit, child: const Text('Cancel')),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _isSavingEdit ? null : _saveEdit,
                icon: _isSavingEdit
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(_isSavingEdit ? 'Saving…' : 'Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ] else if (_viewingEngagement == null &&
              _generatedContent.isEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                tooltip: 'Concept Simplifier',
                style: IconButton.styleFrom(
                    backgroundColor: AppTheme.goldSurface,
                    foregroundColor: AppTheme.gold),
                onPressed: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ConceptSimplifierScreen())),
              ),
            ),
        ],
        bottom: showTabs
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.orange.shade700,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: Colors.orange.shade700,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(
                      icon: Icon(Icons.auto_awesome_rounded, size: 20),
                      text: 'Create'),
                  Tab(
                      icon: Icon(Icons.history_edu_rounded, size: 20),
                      text: 'Saved'),
                ],
              )
            : PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(color: AppTheme.border, height: 1),
              ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_isEditing) return _buildInlineEditor();
    if (_viewingEngagement != null) {
      return _buildHistoryDetail(_viewingEngagement!);
    }
    return TabBarView(
      controller: _tabController,
      children: [_buildCreateTab(), _buildSavedTab()],
    );
  }

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
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.orange.shade600),
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
              style:
                  TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineEditor() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppTheme.goldSurface,
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 14, color: AppTheme.brown),
              Gap(8),
              Expanded(
                child: Text(
                  'Edit the Markdown below. Tap Save when done.',
                  style: TextStyle(fontSize: 12, color: AppTheme.brown),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _editController,
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
                  borderSide: BorderSide(
                      color: Colors.orange.shade600, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Create Tab ────────────────────────────────────────────────────────────

  Widget _buildCreateTab() {
    if (_generatedContent.isNotEmpty) return _buildOutput();
    return _buildForm();
  }

  Widget _buildForm() {
    final plans = ref.watch(planProvider).plans;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _SectionHeader(
              icon: Icons.celebration_rounded,
              iconColor: Colors.orange.shade700,
              iconBg: Colors.orange.shade50,
              title: 'Boost Class Participation',
              subtitle: 'Select sessions or enter a custom topic',
            ),
          ),
          const Gap(16),

          // ── Engagement type ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel(
                    icon: Icons.emoji_events_rounded,
                    label: 'Engagement Type',
                  ),
                  const Gap(12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _types.map((type) {
                      final selected = _selectedType == type['name'];
                      final color = Colors.orange.shade600;
                      return GestureDetector(
                        onTap: () => setState(
                            () => _selectedType = type['name'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withValues(alpha: 0.12)
                                : AppTheme.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? color : AppTheme.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 16,
                                color: selected
                                    ? color
                                    : AppTheme.textSecondary,
                              ),
                              const Gap(6),
                              Text(
                                type['name'] as String,
                                style: TextStyle(
                                  fontSize: 13,
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
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),

          // ── Type-specific options ─────────────────────────────────
          if (_selectedType == 'Quiz') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(
                      icon: Icons.format_list_numbered_rounded,
                      label: 'Number of Questions',
                    ),
                    const Gap(12),
                    Row(
                      children: [
                        for (final n in [3, 5, 10, 15])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _numQuestions = n),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 9),
                                decoration: BoxDecoration(
                                  color: _numQuestions == n
                                      ? Colors.orange.shade600
                                          .withValues(alpha: 0.12)
                                      : AppTheme.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _numQuestions == n
                                        ? Colors.orange.shade600
                                        : AppTheme.border,
                                    width: _numQuestions == n ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  '$n',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _numQuestions == n
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _numQuestions == n
                                        ? Colors.orange.shade700
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: TextField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Custom…',
                              isDense: true,
                            ),
                            onChanged: (v) {
                              final parsed = int.tryParse(v);
                              if (parsed != null && parsed > 0) {
                                setState(() => _numQuestions = parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),
          ] else if (_selectedType == 'Activities') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(
                      icon: Icons.sports_esports_outlined,
                      label: 'Activity Format',
                    ),
                    const Gap(12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Group Activity',
                        'Individual Task',
                        'Role Play',
                        'Game / Competition',
                        'Project-Based',
                        'Hands-On / Lab',
                      ].map((fmt) {
                        final selected = _activityFormat == fmt;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _activityFormat = fmt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.orange.shade600
                                      .withValues(alpha: 0.12)
                                  : AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? Colors.orange.shade600
                                    : AppTheme.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              fmt,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.orange.shade700
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),
          ] else if (_selectedType == 'Discussion') ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _FormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FieldLabel(
                      icon: Icons.forum_outlined,
                      label: 'Discussion Format',
                    ),
                    const Gap(12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        'Think-Pair-Share',
                        'Socratic Seminar',
                        'Fishbowl',
                        'Debate',
                        'Jigsaw',
                        'Four Corners',
                      ].map((fmt) {
                        final selected = _discussionFormat == fmt;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _discussionFormat = fmt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.orange.shade600
                                      .withValues(alpha: 0.12)
                                  : AppTheme.background,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selected
                                    ? Colors.orange.shade600
                                    : AppTheme.border,
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              fmt,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected
                                    ? Colors.orange.shade700
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),
          ],

          // ── Plan/session accordion picker (edge-to-edge, no side margin) ──
          _buildMultiPlanPicker(plans),
          const Gap(16),

          // ── Topic override ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel(
                    icon: Icons.topic_rounded,
                    label: 'Topic',
                    hint: 'Optional — auto-derived from selections',
                  ),
                  const Gap(10),
                  TextField(
                    controller: _topicController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Photosynthesis, Solar System…',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
          const Gap(20),

          // ── Selection summary ────────────────────────────────────────
          if (_totalSelected > 0) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SelectionSummaryBanner(
                sessionCount: _totalSelected,
                planCount: _selectedSessions.values
                    .where((s) => s.isNotEmpty)
                    .length,
              ),
            ),
            const Gap(14),
          ],

          // ── Generate button ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: ElevatedButton.icon(
              onPressed: (_topicController.text.trim().isEmpty &&
                      _totalSelected == 0)
                  ? null
                  : _generate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('Generate Suggestions',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Multi-plan picker (identical pattern to worksheet generator) ───────────

  Widget _buildMultiPlanPicker(List<LessonPlanModel> plans) {
    // Ensure all plans are expanded by default
    for (final p in plans) {
      _expandedPlans.add(p.id);
    }

    if (plans.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.goldSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppTheme.brown.withValues(alpha: 0.2)),
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
                    color: AppTheme.brown, fontSize: 13, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppTheme.border),
        ),
      ),
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
    final someChecked = selectedForPlan.isNotEmpty &&
        selectedForPlan.length < sessions.length;

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => isExpanded
              ? _expandedPlans.remove(plan.id)
              : _expandedPlans.add(plan.id)),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

        // Session list
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
                        final set = _selectedSessions.putIfAbsent(
                            plan.id, () => {});
                        if (isChecked) {
                          set.remove(idx);
                          if (set.isEmpty) _selectedSessions.remove(plan.id);
                        } else {
                          set.add(idx);
                        }
                      }),
                      child: Padding(
                        padding:
                            const EdgeInsets.fromLTRB(52, 10, 16, 10),
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
                  h1: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.orange.shade700),
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
                  onPressed: () => setState(() {
                    _generatedContent = '';
                    _generatedId = null;
                  }),
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
                  onPressed: () => _openEditor(_generatedContent),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade700),
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
                  onPressed: () => _showRegenSheet(
                      currentContent: _generatedContent,
                      engId: _generatedId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
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
            tooltip: 'Download as PDF',
            label: 'Export PDF',
            onExport: () => exportMarkdownToPdf(
              markdownContent: _generatedContent,
              fileName: safeFileName.isNotEmpty
                  ? 'Engagement_$safeFileName'
                  : 'Engagement',
            ),
          ),
        ],
      ),
    );
  }

  // ── Saved Tab ─────────────────────────────────────────────────────────────

  Widget _buildSavedTab() {
    final state = ref.watch(engagementProvider);

    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.orange));
    }

    if (state.engagements.isEmpty) {
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
                child: const Icon(Icons.history_edu_rounded,
                    size: 36, color: AppTheme.textHint),
              ),
              const Gap(20),
              const Text(
                'No engagements yet',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const Gap(6),
              const Text(
                'Switch to Create to generate\nyour first engagement.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // Group by engagement type
    const categories = [
      ('Icebreaker', Icons.ac_unit_rounded, Color(0xFF2196F3)),
      ('Quiz', Icons.quiz_rounded, Color(0xFF9C27B0)),
      ('Activities', Icons.sports_esports_rounded, Color(0xFF4CAF50)),
      ('Discussion', Icons.forum_rounded, Color(0xFFFF9800)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (typeName, icon, color) in categories) ...[
          _buildCategoryBlock(
            state.engagements,
            typeName: typeName,
            icon: icon,
            color: color,
          ),
          const Gap(12),
        ],
      ],
    );
  }

  Widget _buildCategoryBlock(
    List<EngagementModel> all, {
    required String typeName,
    required IconData icon,
    required Color color,
  }) {
    final items = all
        .where((e) => e.engagementType.toLowerCase() == typeName.toLowerCase())
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const Gap(10),
                Text(
                  typeName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${items.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Items or empty state
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline_rounded,
                      size: 16, color: AppTheme.textHint),
                  const Gap(8),
                  Text(
                    'No $typeName saved yet',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textHint),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(10),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Gap(6),
              itemBuilder: (_, i) {
                final eng = items[i];
                return _EngagementListTile(
                  engagement: eng,
                  onTap: () => setState(() {
                    _viewingEngagement = eng;
                    _isEditing = false;
                  }),
                  onDelete: () => _deleteEngagement(eng.id),
                  onRename: () => _showRenameDialog(eng),
                );
              },
            ),
        ],
      ),
    );
  }

  // ── History detail ────────────────────────────────────────────────────────

  Widget _buildHistoryDetail(EngagementModel eng) {
    final safeFileName = eng.topic
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
                data: eng.content,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  h1: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.orange.shade700),
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
        Container(
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
                      icon: const Icon(
                          Icons.drive_file_rename_outline_rounded,
                          size: 16),
                      onPressed: () => _showRenameDialog(eng),
                      label: const Text('Rename'),
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
                      onPressed: () => _openEditor(eng.content),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                        side: BorderSide(color: Colors.orange.shade700),
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
                      onPressed: () => _showRegenSheet(
                          currentContent: eng.content, engId: eng.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
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
              Row(
                children: [
                  Expanded(
                    child: _ExportPdfButton(
                      tooltip: 'Download as PDF',
                      label: 'Export PDF',
                      onExport: () => exportMarkdownToPdf(
                        markdownContent: eng.content,
                        fileName: safeFileName.isNotEmpty
                            ? 'Engagement_$safeFileName'
                            : 'Engagement',
                      ),
                    ),
                  ),
                  const Gap(8),
                  OutlinedButton.icon(
                    icon: Icon(Icons.delete_outline,
                        size: 16, color: Colors.red.shade600),
                    onPressed: () => _deleteEngagement(eng.id),
                    label: Text('Delete',
                        style: TextStyle(color: Colors.red.shade600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.red.shade300),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Reusable form components ──────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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

  const _FieldLabel(
      {required this.icon, required this.label, this.hint});

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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 16, color: Colors.orange.shade700),
          const Gap(8),
          Expanded(
            child: Text(
              '$sessionCount session${sessionCount > 1 ? 's' : ''} from $planCount plan${planCount > 1 ? 's' : ''} selected',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportPdfButton extends StatefulWidget {
  final String tooltip;
  final String label;
  final Future<void> Function() onExport;

  const _ExportPdfButton({
    required this.tooltip,
    required this.label,
    required this.onExport,
  });

  @override
  State<_ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<_ExportPdfButton> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _exporting
            ? null
            : () async {
                setState(() => _exporting = true);
                try {
                  await widget.onExport();
                } finally {
                  if (mounted) setState(() => _exporting = false);
                }
              },
        icon: _exporting
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf_rounded, size: 16),
        label: Text(_exporting ? 'Preparing…' : widget.label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ── Engagement list tile ──────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final String type;

  const _TypeBadge({required this.type});

  static const Map<String, Color> _colors = {
    'Icebreaker': Colors.teal,
    'Quiz': Colors.indigo,
    'Activities': Colors.deepOrange,
    'Discussion': Colors.purple,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[type] ?? Colors.blueGrey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        type,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EngagementListTile extends StatelessWidget {
  final EngagementModel engagement;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _EngagementListTile({
    required this.engagement,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      engagement.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(4),
                    Text(
                      engagement.topic,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Gap(8),
              _TypeBadge(type: engagement.engagementType),
              const Gap(4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert,
                    size: 18, color: AppTheme.textSecondary),
                tooltip: 'Options',
                onSelected: (v) {
                  if (v == 'rename') onRename();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'rename',
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                          Icons.drive_file_rename_outline_rounded,
                          size: 16),
                      title: Text('Rename'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      dense: true,
                      leading: Icon(Icons.delete_outline,
                          size: 16, color: Colors.red.shade400),
                      title: Text('Delete',
                          style:
                              TextStyle(color: Colors.red.shade400)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
