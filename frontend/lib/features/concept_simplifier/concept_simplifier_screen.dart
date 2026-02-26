import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:teacher_ai/core/api/api_service.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/core/utils/pdf_exporter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/providers/plan_provider.dart';
import 'package:teacher_ai/core/providers/simplifier_provider.dart';
import 'package:teacher_ai/features/shell/main_shell.dart';
import 'package:teacher_ai/features/engagement/engagement_screen.dart';

class ConceptSimplifierScreen extends ConsumerStatefulWidget {
  const ConceptSimplifierScreen({super.key});

  @override
  ConsumerState<ConceptSimplifierScreen> createState() =>
      _ConceptSimplifierScreenState();
}

class _ConceptSimplifierScreenState
    extends ConsumerState<ConceptSimplifierScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  final _inputController = TextEditingController();

  late final TabController _tabController;

  bool _isLoading = false;
  String _statusMessage = '';
  String _generatedContent = '';
  int? _generatedId;
  String _originalInput = '';

  // Edit state
  bool _isEditing = false;
  bool _isSavingEdit = false;
  final TextEditingController _editController = TextEditingController();

  // Rename state
  final TextEditingController _renameTitleController = TextEditingController();

  // Viewing saved result
  SimplifierModel? _viewingResult;

  String get _grade => ref.read(shellProvider).selectedGrade ?? '';
  String get _subject => ref.read(shellProvider).selectedSubject ?? '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shell = ref.read(shellProvider);
      ref.read(simplifierProvider.notifier).fetchAll(
            grade: shell.selectedGrade ?? '',
            subject: shell.selectedSubject ?? '',
          );
      final activeTopic = ref.read(planProvider).topic;
      if (activeTopic != null && _inputController.text.isEmpty) {
        _inputController.text = activeTopic;
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inputController.dispose();
    _editController.dispose();
    _renameTitleController.dispose();
    super.dispose();
  }

  // ── Generate ──────────────────────────────────────────────────────────────

  Future<void> _generate() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _generatedContent = '';
      _generatedId = null;
      _originalInput = text;
      _statusMessage = 'Simplifying concept…';
    });

    try {
      final activePlanId = ref.read(planProvider).activePlanId;
      final res = await _apiService.simplifyConcept(
        text,
        planId: activePlanId,
        grade: _grade,
        subject: _subject,
      );
      if (res['success'] == true) {
        final content = res['content'] as String;
        final savedId = res['plan_id'] as int?;
        setState(() {
          _generatedContent = content;
          _generatedId = savedId;
        });
        // Always switch to the Simplify tab so output is visible
        _tabController.animateTo(0);
        if (savedId != null) {
          final result = SimplifierModel(
            id: savedId,
            teacherId: ApiService.teacherId,
            grade: _grade,
            subject: _subject,
            topic: text.length > 200 ? '${text.substring(0, 200)}…' : text,
            content: content,
            planId: activePlanId,
            createdAt: DateTime.now().toIso8601String(),
          );
          ref.read(simplifierProvider.notifier).addResult(result);
        }
      } else {
        final error = res['error'] ?? 'Something went wrong. Please try again.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error'), backgroundColor: Colors.red.shade700),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });
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
      if (_viewingResult != null) {
        await ref
            .read(simplifierProvider.notifier)
            .updateContent(_viewingResult!.id, newContent);
        final updated = ref
            .read(simplifierProvider)
            .results
            .where((r) => r.id == _viewingResult!.id)
            .firstOrNull;
        setState(() {
          _viewingResult =
              updated ?? _viewingResult!.copyWith(content: newContent);
          _isEditing = false;
        });
      } else if (_generatedId != null) {
        await ref
            .read(simplifierProvider.notifier)
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

  void _showRegenSheet({required String currentContent, required int? resultId}) {
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
            const Text('Refine Explanation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Gap(4),
            const Text('What would you like to change?',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            const Gap(12),
            TextField(
              controller: instrCtrl,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Make it even simpler, use more analogies…',
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
                        backgroundColor: Colors.purple.shade600),
                    onPressed: () async {
                      final instr = instrCtrl.text.trim();
                      if (instr.isEmpty) return;
                      Navigator.pop(ctx);
                      await _regenerateWithInstruction(
                          currentContent, instr, resultId);
                    },
                    child: const Text('Refine'),
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
      String original, String instruction, int? resultId) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Refining explanation…';
    });
    try {
      final res = await _apiService.regenerate(
        feature: 'simplifier',
        originalContent: original,
        instruction: instruction,
        planId: null,
      );
      if (res['success'] == true) {
        final newContent = res['content'] as String;
        if (resultId != null) {
          await ref
              .read(simplifierProvider.notifier)
              .updateContent(resultId, newContent);
          if (_viewingResult != null && _viewingResult!.id == resultId) {
            final updated = ref
                .read(simplifierProvider)
                .results
                .where((r) => r.id == resultId)
                .firstOrNull;
            setState(() {
              _viewingResult =
                  updated ?? _viewingResult!.copyWith(content: newContent);
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

  void _showRenameDialog(SimplifierModel result) {
    _renameTitleController.text = result.title ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: TextField(
          controller: _renameTitleController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter a title…'),
          onSubmitted: (_) => _doRename(ctx, result),
        ),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          const Gap(8),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.purple.shade600),
            onPressed: () => _doRename(ctx, result),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _doRename(BuildContext ctx, SimplifierModel result) async {
    final title = _renameTitleController.text.trim();
    Navigator.pop(ctx);
    if (title.isEmpty) return;
    await ref.read(simplifierProvider.notifier).renameResult(result.id, title);
    if (_viewingResult?.id == result.id) {
      final updated = ref
          .read(simplifierProvider)
          .results
          .where((r) => r.id == result.id)
          .firstOrNull;
      setState(() {
        _viewingResult = updated ?? result.copyWith(title: title);
      });
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _deleteResult(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Explanation?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(simplifierProvider.notifier).deleteResult(id);
      if (_viewingResult?.id == id) {
        setState(() {
          _viewingResult = null;
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
        _viewingResult == null && !_isEditing && !_isLoading;

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
            if (_isEditing) { _cancelEdit(); return; }
            if (_viewingResult != null) {
              setState(() => _viewingResult = null); return;
            }
            if (_generatedContent.isNotEmpty) {
              setState(() { _generatedContent = ''; _generatedId = null; }); return;
            }
            Navigator.canPop(context)
                ? Navigator.pop(context)
                : Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const EngagementSuggestionScreen()));
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _isEditing
                  ? 'Edit Explanation'
                  : _viewingResult != null
                      ? _viewingResult!.displayName
                      : 'Concept Simplifier',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
            if (grade.isNotEmpty && subject.isNotEmpty)
              Text('$grade · $subject',
                  style: const TextStyle(
                      fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          if (_isEditing) ...[
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton(onPressed: _cancelEdit, child: const Text('Cancel')),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton.icon(
                onPressed: _isSavingEdit ? null : _saveEdit,
                icon: _isSavingEdit
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(_isSavingEdit ? 'Saving…' : 'Save'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.purple.shade600,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ),
          ],
        ],
        bottom: showTabs
            ? TabBar(
                controller: _tabController,
                labelColor: Colors.purple.shade700,
                unselectedLabelColor: AppTheme.textSecondary,
                indicatorColor: Colors.purple.shade700,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.auto_awesome_rounded, size: 20), text: 'Simplify'),
                  Tab(icon: Icon(Icons.history_edu_rounded, size: 20), text: 'Saved'),
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
    if (_viewingResult != null) return _buildDetail(_viewingResult!);
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
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: Colors.purple.shade50, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: CircularProgressIndicator(
                    strokeWidth: 3, color: Colors.purple.shade600),
              ),
            ),
            const Gap(24),
            Text(_statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600)),
            const Gap(8),
            const Text('This may take a few seconds…',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
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
          color: Colors.purple.shade50,
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.purple),
              Gap(8),
              Expanded(
                child: Text('Edit the Markdown below. Tap Save when done.',
                    style: TextStyle(fontSize: 12, color: Colors.purple)),
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
                  borderSide:
                      BorderSide(color: Colors.purple.shade600, width: 2),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.auto_fix_high_rounded,
                    color: Colors.purple.shade700, size: 22),
              ),
              const Gap(12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Explain Like I\'m Five',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppTheme.textPrimary)),
                    Text('Enter any complex topic or text to simplify',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const Gap(20),

          // Input card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: AppTheme.brown),
                    Gap(6),
                    Text('Concept or Text',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppTheme.textPrimary)),
                  ],
                ),
                const Gap(10),
                TextField(
                  controller: _inputController,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText:
                        'e.g. "Quantum entanglement", "The French Revolution", or paste any complex text…',
                    hintStyle: const TextStyle(
                        fontSize: 13, color: AppTheme.textHint),
                    filled: true,
                    fillColor: AppTheme.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          BorderSide(color: Colors.purple.shade600, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Gap(20),

          ElevatedButton.icon(
            onPressed: _inputController.text.trim().isEmpty ? null : _generate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Simplify Now',
                style:
                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Generated output ──────────────────────────────────────────────────────

  Widget _buildOutput() {
    final safeFileName = _originalInput
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Original input banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.format_quote_rounded,
                          size: 16, color: Colors.purple.shade400),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          _originalInput.length > 120
                              ? '${_originalInput.substring(0, 120)}…'
                              : _originalInput,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade700,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                // Content card
                Container(
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
                    styleSheet: _markdownStyle(),
                  ),
                ),
              ],
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
                    foregroundColor: Colors.purple.shade700,
                    side: BorderSide(color: Colors.purple.shade700),
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
                      resultId: _generatedId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  label: const Text('Refine'),
                ),
              ),
            ],
          ),
          const Gap(10),
          _ExportPdfButton(
            label: 'Export PDF',
            onExport: () => exportMarkdownToPdf(
              markdownContent: _generatedContent,
              fileName: safeFileName.isNotEmpty
                  ? 'Explanation_$safeFileName'
                  : 'Explanation',
            ),
          ),
        ],
      ),
    );
  }

  // ── Saved Tab ─────────────────────────────────────────────────────────────

  Widget _buildSavedTab() {
    final state = ref.watch(simplifierProvider);

    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.purple));
    }

    if (state.results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80, height: 80,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceAlt, shape: BoxShape.circle),
                child: const Icon(Icons.auto_fix_high_rounded,
                    size: 36, color: AppTheme.textHint),
              ),
              const Gap(20),
              const Text('No explanations yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary)),
              const Gap(6),
              const Text(
                'Switch to Simplify to generate\nyour first explanation.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // Single block — all saved simplifications
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSavedBlock(state.results),
      ],
    );
  }

  Widget _buildSavedBlock(List<SimplifierModel> items) {
    const color = Color(0xFF9C27B0);

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
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                  bottom: BorderSide(color: color.withValues(alpha: 0.15))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_fix_high_rounded,
                      size: 18, color: color),
                ),
                const Gap(10),
                const Text('Saved Explanations',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${items.length}',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ),
              ],
            ),
          ),
          // Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(10),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Gap(6),
            itemBuilder: (_, i) {
              final r = items[i];
              return _SimplifierListTile(
                result: r,
                onTap: () => setState(() {
                  _viewingResult = r;
                  _isEditing = false;
                }),
                onDelete: () => _deleteResult(r.id),
                onRename: () => _showRenameDialog(r),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Detail view ───────────────────────────────────────────────────────────

  Widget _buildDetail(SimplifierModel result) {
    final safeFileName = result.topic
        .replaceAll(RegExp(r'[^\w\s-]'), '')
        .trim()
        .replaceAll(' ', '_');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Topic banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade100),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.format_quote_rounded,
                          size: 16, color: Colors.purple.shade400),
                      const Gap(8),
                      Expanded(
                        child: Text(
                          result.topic.length > 120
                              ? '${result.topic.substring(0, 120)}…'
                              : result.topic,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade700,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(12),
                Container(
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
                    data: result.content,
                    selectable: true,
                    styleSheet: _markdownStyle(),
                  ),
                ),
              ],
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
                          Icons.drive_file_rename_outline_rounded, size: 16),
                      onPressed: () => _showRenameDialog(result),
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
                      onPressed: () => _openEditor(result.content),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple.shade700,
                        side: BorderSide(color: Colors.purple.shade700),
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
                          currentContent: result.content,
                          resultId: result.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      label: const Text('Refine'),
                    ),
                  ),
                ],
              ),
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: _ExportPdfButton(
                      label: 'Export PDF',
                      onExport: () => exportMarkdownToPdf(
                        markdownContent: result.content,
                        fileName: safeFileName.isNotEmpty
                            ? 'Explanation_$safeFileName'
                            : 'Explanation',
                      ),
                    ),
                  ),
                  const Gap(8),
                  OutlinedButton.icon(
                    icon: Icon(Icons.delete_outline,
                        size: 16, color: Colors.red.shade600),
                    onPressed: () => _deleteResult(result.id),
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

  MarkdownStyleSheet _markdownStyle() => MarkdownStyleSheet(
        h1: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.purple.shade700),
        h2: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppTheme.textPrimary),
        p: const TextStyle(height: 1.6, fontSize: 14),
        listBullet: const TextStyle(fontSize: 14),
      );
}

// ── List tile ──────────────────────────────────────────────────────────────────

class _SimplifierListTile extends StatelessWidget {
  final SimplifierModel result;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onRename;

  const _SimplifierListTile({
    required this.result,
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_fix_high_rounded,
                    size: 16, color: Colors.purple.shade600),
              ),
              const Gap(10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Gap(2),
                    Text(
                      result.createdAt.substring(0, 10),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textHint),
                    ),
                  ],
                ),
              ),
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
                          Icons.drive_file_rename_outline_rounded, size: 16),
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
                          style: TextStyle(color: Colors.red.shade400)),
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

// ── PDF export button ──────────────────────────────────────────────────────────

class _ExportPdfButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onExport;

  const _ExportPdfButton({required this.label, required this.onExport});

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
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.picture_as_pdf_rounded, size: 16),
        label: Text(_exporting ? 'Preparing…' : widget.label),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
