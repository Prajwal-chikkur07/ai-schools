import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:teacher_ai/core/api/api_service.dart';
import 'package:teacher_ai/core/components/sprout_components.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/providers/plan_provider.dart';
import 'package:teacher_ai/features/worksheet_generator/worksheet_generator_screen.dart';

class LessonPlannerScreen extends ConsumerStatefulWidget {
  final String? grade;
  final String? subject;
  const LessonPlannerScreen({super.key, this.grade, this.subject});

  @override
  ConsumerState<LessonPlannerScreen> createState() =>
      _LessonPlannerScreenState();
}

class _PlanSection {
  final String heading;
  String body;
  _PlanSection({required this.heading, required this.body});
}

class _LessonPlannerScreenState extends ConsumerState<LessonPlannerScreen> {
  final _apiService = ApiService();
  final _topicController = TextEditingController();
  final _lecturesController = TextEditingController(text: '1');
  final _conceptsController = TextEditingController();
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String _generatedContent = '';
  int? _generatedPlanId;
  bool _isLoading = false;
  bool _isSaved = false;
  String _statusMessage = 'Preparing…';

  List<_PlanSection> _sections = [];
  int? _selectedSectionIndex;
  bool _isSectionRegenerating = false;

  List<_PlanSection> _parseSections(String content) {
    final lines = content.split('\n');
    final sections = <_PlanSection>[];
    String? currentHeading;
    final bodyLines = <String>[];
    for (final line in lines) {
      if (line.startsWith('## ') || line.startsWith('# ')) {
        if (currentHeading != null || bodyLines.isNotEmpty) {
          sections.add(_PlanSection(
            heading: currentHeading ?? '',
            body: bodyLines.join('\n').trim(),
          ));
          bodyLines.clear();
        }
        currentHeading = line;
      } else {
        bodyLines.add(line);
      }
    }
    if (currentHeading != null || bodyLines.isNotEmpty) {
      sections.add(_PlanSection(
        heading: currentHeading ?? '',
        body: bodyLines.join('\n').trim(),
      ));
    }
    return sections;
  }

  String _rebuildContent() {
    return _sections.map((s) {
      final parts = <String>[];
      if (s.heading.isNotEmpty) parts.add(s.heading);
      if (s.body.isNotEmpty) parts.add(s.body);
      return parts.join('\n\n');
    }).join('\n\n');
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedFileBytes = result.files.single.bytes!;
        _selectedFileName = result.files.single.name;
      });
    }
  }

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Analyzing requirements…';
    });
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() => _statusMessage = _selectedFileBytes != null
        ? 'Processing PDF context…'
        : 'Building lesson outline…');

    try {
      final numLectures = int.tryParse(_lecturesController.text) ?? 1;
      final res = await _apiService.generateLesson(
        grade: widget.grade!,
        subject: widget.subject!,
        topic: _topicController.text,
        lectures: numLectures,
        concepts: _conceptsController.text.isEmpty
            ? null
            : _conceptsController.text,
        fileBytes: _selectedFileBytes,
        fileName: _selectedFileName,
      );
      if (res['success']) {
        final planId = res['plan_id'] != null
            ? int.tryParse(res['plan_id'].toString())
            : null;
        final content = res['content'] as String;
        setState(() {
          _generatedContent = content;
          _sections = _parseSections(content);
          _generatedPlanId = planId;
          _isSaved = false;
          _selectedSectionIndex = null;
        });
        if (planId != null) {
          ref.read(planProvider.notifier).addNewPlan(LessonPlanModel(
            id: planId,
            teacherId: ApiService.teacherId,
            grade: widget.grade!,
            subject: widget.subject!,
            topic: _topicController.text,
            numLectures: numLectures,
            content: content,
            createdAt: DateTime.now().toIso8601String(),
          ));
          ref.read(planProvider.notifier).setActivePlan(planId);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${res['error'] ?? 'Unknown'}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _regenerateSection(int index) async {
    final section = _sections[index];
    final sectionText = '${section.heading}\n\n${section.body}';
    const instruction =
        'Rewrite this section with richer explanations, more detail, and better examples. '
        'Keep the same heading and structure but improve the content quality.';
    setState(() {
      _isSectionRegenerating = true;
      _statusMessage = 'Regenerating section…';
    });
    try {
      final res = await _apiService.regenerate(
        feature: 'lesson',
        originalContent: sectionText,
        instruction: instruction,
        planId: _generatedPlanId,
      );
      if (res['success'] == true) {
        final newText = res['content'] as String;
        final newLines = newText.split('\n');
        String newBody = newText;
        if (newLines.isNotEmpty && newLines.first.startsWith('#')) {
          newBody = newLines.skip(1).join('\n').trim();
        }
        setState(() {
          _sections[index].body = newBody;
          _generatedContent = _rebuildContent();
          _selectedSectionIndex = null;
          _isSaved = false;
        });
        if (_generatedPlanId != null) {
          await _apiService.updatePlan(_generatedPlanId!, _generatedContent);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                Gap(8),
                Text('Section regenerated!'),
              ]),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isSectionRegenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = (widget.grade != null && widget.subject != null)
        ? '${widget.grade} · ${widget.subject}'
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Lesson Planner',
                style:
                    TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (subtitle != null)
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              tooltip: 'Worksheet Generator',
              style: IconButton.styleFrom(
                  backgroundColor: AppTheme.goldSurface,
                  foregroundColor: AppTheme.brown),
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) => const WorksheetGeneratorScreen()),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppTheme.border, height: 1)),
      ),
      body: (_isLoading || _isSectionRegenerating)
          ? _buildLoadingState()
          : _buildContent(),
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
              decoration: const BoxDecoration(
                  color: AppTheme.goldSurface, shape: BoxShape.circle),
              child: const Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: AppTheme.brown),
              ),
            ),
            const Gap(24),
            FadeInTransition(
              child: Text(_statusMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ),
            const Gap(8),
            const Text('This usually takes 10–15 seconds',
                style: TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_generatedContent.isNotEmpty) return _buildOutput();

    if (widget.grade == null || widget.subject == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.touch_app_outlined,
                  size: 48, color: AppTheme.textHint),
              const Gap(16),
              const Text('No grade/subject selected',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const Gap(8),
              const Text('Go to Home and pick a grade → subject first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              const Gap(24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.home_rounded, size: 16),
                label: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.goldSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_stories_rounded,
                    color: AppTheme.brown, size: 22),
              ),
              const Gap(12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What will you teach next?',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Provide a topic or upload a reference PDF.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const Gap(24),

          // Topic
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(icon: Icons.topic_rounded, label: 'Topic *'),
                const Gap(10),
                TextField(
                  controller: _topicController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      hintText: 'e.g. Introduction to Quantum Physics'),
                ),
              ],
            ),
          ),
          const Gap(10),

          // Key concepts
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(
                    icon: Icons.list_alt_rounded,
                    label: 'Key Concepts',
                    hint: 'Optional'),
                const Gap(10),
                TextField(
                  controller: _conceptsController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        '• Newton\'s Laws of Motion\n• Gravitational Force\n• Work and Energy',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          const Gap(10),

          // Number of sessions
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(
                    icon: Icons.school_outlined,
                    label: 'Number of Sessions'),
                const Gap(10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lecturesController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                            hintText: '3', suffixText: 'sessions'),
                      ),
                    ),
                    const Gap(10),
                    ...['1', '3', '5', '8'].map((n) {
                      final sel = _lecturesController.text == n;
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _lecturesController.text = n),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: sel ? AppTheme.brown : AppTheme.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: sel
                                      ? AppTheme.brown
                                      : AppTheme.border),
                            ),
                            child: Center(
                              child: Text(n,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : AppTheme.textSecondary)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const Gap(4),
                const Text('Each session is ~45 minutes',
                    style: TextStyle(
                        fontSize: 11, color: AppTheme.textHint)),
              ],
            ),
          ),
          const Gap(10),

          // PDF upload
          _FormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(
                    icon: Icons.upload_file_rounded,
                    label: 'Reference PDF',
                    hint: 'Optional'),
                const Gap(10),
                GestureDetector(
                  onTap: _pickFile,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 90,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _selectedFileName != null
                          ? AppTheme.goldSurface
                          : AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedFileName != null
                            ? AppTheme.brown.withValues(alpha: 0.4)
                            : AppTheme.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedFileName != null
                              ? Icons.check_circle_rounded
                              : Icons.cloud_upload_outlined,
                          color: _selectedFileName != null
                              ? AppTheme.brown
                              : AppTheme.textHint,
                          size: 28,
                        ),
                        const Gap(6),
                        Text(
                          _selectedFileName ?? 'Tap to upload PDF',
                          style: TextStyle(
                              color: _selectedFileName != null
                                  ? AppTheme.brown
                                  : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(24),

          // Generate button
          ElevatedButton.icon(
            onPressed: (_topicController.text.trim().isEmpty ||
                    _lecturesController.text.trim().isEmpty)
                ? null
                : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brown,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Generate Lesson Plan',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput() {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hint banner
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.goldSurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.brown.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.touch_app_rounded,
                        color: AppTheme.brown, size: 16),
                    Gap(8),
                    Expanded(
                      child: Text(
                        'Tap any section to select it, then regenerate just that part.',
                        style: TextStyle(
                            color: AppTheme.brown, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap(14),

              ..._sections.asMap().entries.map((entry) {
                final i = entry.key;
                final section = entry.value;
                final isSelected = _selectedSectionIndex == i;
                final sectionMd =
                    '${section.heading.isNotEmpty ? "${section.heading}\n\n" : ""}${section.body}';

                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedSectionIndex = isSelected ? null : i;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.brown
                            : AppTheme.border,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                  color: AppTheme.brown
                                      .withValues(alpha: 0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3))
                            ]
                          : [],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: MarkdownBody(
                            data: sectionMd,
                            selectable: false,
                            styleSheet: MarkdownStyleSheet(
                              h1: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: AppTheme.brown),
                              h2: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                              h3: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppTheme.textPrimary),
                              p: const TextStyle(
                                  height: 1.6, fontSize: 14),
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            decoration: const BoxDecoration(
                              color: AppTheme.goldSurface,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(Icons.auto_fix_high_rounded,
                                    color: AppTheme.brown, size: 16),
                                const Gap(8),
                                const Expanded(
                                  child: Text('Section selected',
                                      style: TextStyle(
                                          color: AppTheme.brown,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                ),
                                FilledButton.icon(
                                  onPressed: () => _regenerateSection(i),
                                  icon: const Icon(Icons.refresh_rounded,
                                      size: 14),
                                  label: const Text('Regenerate',
                                      style: TextStyle(fontSize: 12)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppTheme.brown,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Delete button
        if (_generatedPlanId != null)
          Positioned(
            top: 12,
            right: 12,
            child: IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.danger),
              tooltip: 'Delete plan',
              style: IconButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete Plan?',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    content: const Text(
                        'Permanently delete this plan? This cannot be undone.'),
                    actionsPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    actions: [
                      OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      const Gap(8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.danger),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && _generatedPlanId != null) {
                  await ref
                      .read(planProvider.notifier)
                      .deletePlan(_generatedPlanId!);
                  if (mounted) {
                    setState(() {
                      _generatedContent = '';
                      _sections = [];
                      _generatedPlanId = null;
                      _selectedSectionIndex = null;
                    });
                  }
                }
              },
            ),
          ),

        // Bottom action bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppTheme.background.withValues(alpha: 0),
                  AppTheme.background,
                  AppTheme.background,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _isSaved
                      ? null
                      : () async {
                          if (_generatedPlanId != null) {
                            await _apiService.updatePlan(
                                _generatedPlanId!, _generatedContent);
                            ref
                                .read(planProvider.notifier)
                                .updatePlanContent(
                                    _generatedPlanId!, _generatedContent);
                          }
                          setState(() => _isSaved = true);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(children: [
                                  Icon(Icons.check_circle_rounded,
                                      color: Colors.white),
                                  Gap(8),
                                  Text('Lesson plan saved!'),
                                ]),
                                backgroundColor: AppTheme.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor:
                        _isSaved ? AppTheme.success : AppTheme.brown,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: Icon(
                      _isSaved ? Icons.check_rounded : Icons.save_rounded,
                      size: 18),
                  label: Text(_isSaved ? 'Saved ✓' : 'Save Plan',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                const Gap(10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _generatedContent = '';
                            _sections = [];
                            _selectedSectionIndex = null;
                            _isSaved = false;
                          });
                          _generate();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Regenerate'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppTheme.brown),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const Gap(10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.home_rounded, size: 16),
                        label: const Text('Dashboard'),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shared form components ────────────────────────────────────────────────────

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
        Icon(icon, size: 15, color: AppTheme.brown),
        const Gap(6),
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppTheme.textPrimary)),
        if (hint != null) ...[
          const Gap(6),
          Text(hint!,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textHint)),
        ],
      ],
    );
  }
}
