import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/core/providers/grade_subject_provider.dart';

class ManageGradesSubjectsScreen extends ConsumerStatefulWidget {
  const ManageGradesSubjectsScreen({super.key});

  @override
  ConsumerState<ManageGradesSubjectsScreen> createState() =>
      _ManageGradesSubjectsScreenState();
}

class _ManageGradesSubjectsScreenState
    extends ConsumerState<ManageGradesSubjectsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _gradeController = TextEditingController();
  final _subjectController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gradeController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  // ── Grades tab ────────────────────────────────────────────────────────────

  Widget _buildGradesTab(GradeSubjectState gs) {
    return Column(
      children: [
        _AddItemRow(
          controller: _gradeController,
          hint: 'e.g. Grade 11 or Kindergarten',
          label: 'Add Grade',
          onAdd: () {
            final text = _gradeController.text;
            if (text.trim().isEmpty) return;
            if (gs.grades.contains(text.trim())) {
              _showDuplicateSnack('Grade "${text.trim()}" already exists.');
              return;
            }
            ref.read(gradeSubjectProvider.notifier).addGrade(text);
            _gradeController.clear();
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: gs.grades.isEmpty
              ? const _EmptyHint(message: 'No grades yet. Add one above.')
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: gs.grades.length,
                  onReorder: (oldIndex, newIndex) {
                    // Reorder support: build updated list and save
                    final updated = List<String>.from(gs.grades);
                    if (newIndex > oldIndex) newIndex--;
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    _reorderGrades(updated);
                  },
                  itemBuilder: (context, index) {
                    final grade = gs.grades[index];
                    return _ItemTile(
                      key: ValueKey(grade),
                      label: grade,
                      icon: Icons.school_rounded,
                      iconColor: AppTheme.primary,
                      onDelete: () => _confirmDelete(
                        label: grade,
                        type: 'grade',
                        onConfirm: () => ref
                            .read(gradeSubjectProvider.notifier)
                            .removeGrade(grade),
                      ),
                    );
                  },
                ),
        ),
        _ResetBar(
          onReset: () => _confirmReset(
            type: 'grades',
            onConfirm: () =>
                ref.read(gradeSubjectProvider.notifier).resetGrades(),
          ),
        ),
      ],
    );
  }

  // ── Subjects tab ──────────────────────────────────────────────────────────

  Widget _buildSubjectsTab(GradeSubjectState gs) {
    return Column(
      children: [
        _AddItemRow(
          controller: _subjectController,
          hint: 'e.g. Computer Science or Art',
          label: 'Add Subject',
          onAdd: () {
            final text = _subjectController.text;
            if (text.trim().isEmpty) return;
            if (gs.subjects.contains(text.trim())) {
              _showDuplicateSnack('Subject "${text.trim()}" already exists.');
              return;
            }
            ref.read(gradeSubjectProvider.notifier).addSubject(text);
            _subjectController.clear();
          },
        ),
        const Divider(height: 1),
        Expanded(
          child: gs.subjects.isEmpty
              ? const _EmptyHint(message: 'No subjects yet. Add one above.')
              : ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: gs.subjects.length,
                  onReorder: (oldIndex, newIndex) {
                    final updated = List<String>.from(gs.subjects);
                    if (newIndex > oldIndex) newIndex--;
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    _reorderSubjects(updated);
                  },
                  itemBuilder: (context, index) {
                    final subject = gs.subjects[index];
                    return _ItemTile(
                      key: ValueKey(subject),
                      label: subject,
                      icon: Icons.menu_book_rounded,
                      iconColor: AppTheme.secondary,
                      onDelete: () => _confirmDelete(
                        label: subject,
                        type: 'subject',
                        onConfirm: () => ref
                            .read(gradeSubjectProvider.notifier)
                            .removeSubject(subject),
                      ),
                    );
                  },
                ),
        ),
        _ResetBar(
          onReset: () => _confirmReset(
            type: 'subjects',
            onConfirm: () =>
                ref.read(gradeSubjectProvider.notifier).resetSubjects(),
          ),
        ),
      ],
    );
  }

  // ── Reorder helpers ───────────────────────────────────────────────────────

  void _reorderGrades(List<String> updated) {
    final notifier = ref.read(gradeSubjectProvider.notifier);
    _applyGradeOrder(notifier, updated);
  }

  void _reorderSubjects(List<String> updated) {
    final notifier = ref.read(gradeSubjectProvider.notifier);
    _applySubjectOrder(notifier, updated);
  }

  Future<void> _applyGradeOrder(
      GradeSubjectNotifier notifier, List<String> ordered) async {
    // Remove all then re-add in the new order
    final current = ref.read(gradeSubjectProvider).grades.toList();
    for (final g in current) {
      await notifier.removeGrade(g);
    }
    for (final g in ordered) {
      await notifier.addGrade(g);
    }
  }

  Future<void> _applySubjectOrder(
      GradeSubjectNotifier notifier, List<String> ordered) async {
    final current = ref.read(gradeSubjectProvider).subjects.toList();
    for (final s in current) {
      await notifier.removeSubject(s);
    }
    for (final s in ordered) {
      await notifier.addSubject(s);
    }
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  void _confirmDelete({
    required String label,
    required String type,
    required VoidCallback onConfirm,
  }) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove $type?',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'Are you sure you want to remove "$label"?\n'
          'Existing lesson plans using this $type will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmReset({
    required String type,
    required VoidCallback onConfirm,
  }) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset $type?',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
          'This will restore the default list of $type and remove any custom ones you added.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.accent),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Reset to Defaults'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final gs = ref.watch(gradeSubjectProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Manage Grades & Subjects'),
        backgroundColor: AppTheme.surface,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.school_rounded),
              child: Text('Grades (${gs.grades.length})'),
            ),
            Tab(
              icon: const Icon(Icons.menu_book_rounded),
              child: Text('Subjects (${gs.subjects.length})'),
            ),
          ],
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGradesTab(gs),
          _buildSubjectsTab(gs),
        ],
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _AddItemRow extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String label;
  final VoidCallback onAdd;

  const _AddItemRow({
    required this.controller,
    required this.hint,
    required this.label,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                    color: AppTheme.textHint, fontSize: 14),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.background,
              ),
              onSubmitted: (_) => onAdd(),
              textInputAction: TextInputAction.done,
            ),
          ),
          const Gap(12),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onDelete;

  const _ItemTile({
    super.key,
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.drag_handle_rounded,
                color: AppTheme.textHint, size: 20),
            const Gap(4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppTheme.danger, size: 20),
              onPressed: onDelete,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetBar extends StatelessWidget {
  final VoidCallback onReset;

  const _ResetBar({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.restore_rounded,
              size: 16, color: AppTheme.textSecondary),
          const Gap(8),
          const Expanded(
            child: Text(
              'Changed your mind? You can reset to the default list.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onReset,
            child: const Text('Reset Defaults',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textHint),
          const Gap(12),
          Text(message,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }
}
