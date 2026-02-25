import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gap/gap.dart';
import 'package:teacher_ai/core/api/api_service.dart';
import 'package:teacher_ai/core/components/sprout_components.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/providers/plan_provider.dart';
import 'package:teacher_ai/core/providers/grade_subject_provider.dart';
import 'package:teacher_ai/core/utils/pdf_exporter.dart';
import 'package:teacher_ai/features/shell/main_shell.dart';
import 'package:teacher_ai/features/lesson_planner/lesson_planner_screen.dart';
import 'package:teacher_ai/features/worksheet_generator/worksheet_generator_screen.dart';
import 'package:teacher_ai/features/engagement/engagement_screen.dart';
import 'package:teacher_ai/features/concept_simplifier/concept_simplifier_screen.dart';
import 'package:teacher_ai/features/settings/manage_grades_subjects_screen.dart';
import 'package:teacher_ai/features/settings/settings_screen.dart';
import 'package:teacher_ai/features/profile/profile_screen.dart';

// Breakpoint: anything >= 700 wide is "desktop/tablet" layout
const _kDesktopBreak = 700.0;

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? selectedGrade;
  String? selectedSubject;
  int _selectedLectureIndex = 0;
  final Map<int, TextEditingController> _lectureTitleControllers = {};
  final Set<int> _editingLectureIndices = {};

  // Mobile: which plan is expanded in list
  bool _showPlanList = true; // mobile: toggle between list & detail

  void _selectGrade(String grade) {
    setState(() {
      selectedGrade = grade;
      selectedSubject = null;
      _selectedLectureIndex = 0;
      _lectureTitleControllers.clear();
      _editingLectureIndices.clear();
      _showPlanList = true;
    });
    ref.read(planProvider.notifier).clearActivePlan();
  }

  void _selectSubject(String subject) {
    setState(() {
      selectedSubject = subject;
      _selectedLectureIndex = 0;
      _lectureTitleControllers.clear();
      _editingLectureIndices.clear();
      _showPlanList = true;
    });
    ref.read(shellProvider.notifier).setLocation(selectedGrade!, subject);
    ref.read(planProvider.notifier).fetchPlans(
      grade: selectedGrade!,
      subject: subject,
    );
  }

  void _refreshPlans() {
    if (selectedGrade != null && selectedSubject != null) {
      ref.read(planProvider.notifier).fetchPlans(
        grade: selectedGrade!,
        subject: selectedSubject!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= _kDesktopBreak;
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(isDesktop),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 28 : 16,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMainFlow(isDesktop),
                    const Gap(40),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  SliverAppBar _buildAppBar(bool isDesktop) {
    return SliverAppBar(
      expandedHeight: isDesktop ? 100 : 90,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF3D1F0D), Color(0xFF5A2E1C), Color(0xFF7A4030)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.gold.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.eco_rounded,
                        color: AppTheme.gold, size: 22),
                  ),
                  const Gap(10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sprout AI',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3),
                      ),
                      Text(
                        'Teacher Assistant',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 11,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const Spacer(),
                  _AppBarButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Reset',
                    onTap: () {
                      ref.read(planProvider.notifier).clearActivePlan();
                      ref.read(shellProvider.notifier).clearLocation();
                      setState(() {
                        selectedGrade = null;
                        selectedSubject = null;
                        _selectedLectureIndex = 0;
                        _lectureTitleControllers.clear();
                        _editingLectureIndices.clear();
                        _showPlanList = true;
                      });
                    },
                  ),
                  const Gap(6),
                  _AppBarButton(
                    icon: Icons.settings_outlined,
                    tooltip: 'Settings',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen())),
                  ),
                  const Gap(10),
                  GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen())),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.4), width: 2),
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        radius: 16,
                        child: const Text('SJ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Main flow ─────────────────────────────────────────────────────────────

  Widget _buildMainFlow(bool isDesktop) {
    final gs = ref.watch(gradeSubjectProvider);

    if (selectedGrade == null) {
      return _buildGrid('Select Grade', gs.grades, _selectGrade,
          isDesktop: isDesktop, showBack: false);
    }
    if (selectedSubject == null) {
      return _buildGrid('Select Subject', gs.subjects, _selectSubject,
          isDesktop: isDesktop,
          showBack: true,
          onBack: () => setState(() {
                selectedGrade = null;
                selectedSubject = null;
                _selectedLectureIndex = 0;
                _lectureTitleControllers.clear();
                _editingLectureIndices.clear();
              }));
    }

    final planState = ref.watch(planProvider);
    final plans = planState.plans;
    final activeIsValid = planState.activePlanId != null &&
        plans.any((p) => p.id == planState.activePlanId);
    if (!activeIsValid && plans.isNotEmpty && !planState.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(planProvider.notifier).setActivePlan(plans.first.id);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBreadcrumbs(),
        const Gap(24),

        // Quick Tools
        _SectionLabel(icon: Icons.bolt_rounded, color: AppTheme.gold, label: 'Quick Tools'),
        const Gap(12),
        _buildFeatureIcons(isDesktop),
        const Gap(28),

        // Lesson Plans
        Row(
          children: [
            const _SectionLabel(
                icon: Icons.menu_book_rounded,
                color: AppTheme.brown,
                label: 'Lesson Plans'),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh_rounded,
                  size: 18, color: AppTheme.textSecondary),
              tooltip: 'Refresh',
              onPressed: _refreshPlans,
              style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        ),
        const Gap(12),
        if (planState.isLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppTheme.brown)))
        else if (plans.isEmpty)
          _buildEmptyPlanState()
        else if (isDesktop)
          _buildDesktopSplitView(planState)
        else
          _buildMobilePlanView(planState),
      ],
    );
  }

  // ── Desktop: side-by-side ──────────────────────────────────────────────────

  Widget _buildDesktopSplitView(PlanListState state) {
    final plans = state.plans;
    final activePlan = state.activePlan;

    return Container(
      constraints: const BoxConstraints(minHeight: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left sidebar
            Container(
              width: 220,
              decoration: BoxDecoration(
                color: AppTheme.surfaceWarm,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20)),
                border:
                    Border(right: BorderSide(color: AppTheme.border)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text('Plans',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: AppTheme.textPrimary)),
                  ),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: plans.length,
                      itemBuilder: (_, i) =>
                          _PlanListTile(
                        plan: plans[i],
                        isActive: plans[i].id == state.activePlanId,
                        onTap: () => setState(() {
                          ref
                              .read(planProvider.notifier)
                              .setActivePlan(plans[i].id);
                          _selectedLectureIndex = 0;
                          _lectureTitleControllers.clear();
                          _editingLectureIndices.clear();
                        }),
                        onDelete: () => _confirmDeletePlan(plans[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Right panel
            Expanded(
              child: _buildRightPanel(activePlan, isDesktop: true),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile: stacked list → detail ─────────────────────────────────────────

  Widget _buildMobilePlanView(PlanListState state) {
    final plans = state.plans;

    if (!_showPlanList) {
      // Detail view
      return Column(
        children: [
          // Back to list button
          GestureDetector(
            onTap: () => setState(() => _showPlanList = true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.goldSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppTheme.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.arrow_back_rounded,
                      size: 16, color: AppTheme.brown),
                  Gap(6),
                  Text('All Plans',
                      style: TextStyle(
                          color: AppTheme.brown,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          const Gap(12),
          Container(
            constraints: const BoxConstraints(minHeight: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: _buildRightPanel(state.activePlan, isDesktop: false),
          ),
        ],
      );
    }

    // Plan list
    return Column(
      children: plans.asMap().entries.map((e) {
        final plan = e.value;
        final isActive = plan.id == state.activePlanId;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppTheme.gold.withValues(alpha: 0.6)
                  : AppTheme.border,
              width: isActive ? 2 : 1,
            ),
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? AppTheme.goldSurface
                    : AppTheme.surfaceAlt,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.description_outlined,
                  color: isActive
                      ? AppTheme.brown
                      : AppTheme.textSecondary,
                  size: 18),
            ),
            title: Text(
              plan.topic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: AppTheme.textPrimary),
            ),
            subtitle: Text(
              '${plan.numLectures} sessions',
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.textSecondary),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppTheme.danger),
                  onPressed: () => _confirmDeletePlan(plan),
                  style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: AppTheme.textHint),
              ],
            ),
            onTap: () => setState(() {
              ref.read(planProvider.notifier).setActivePlan(plan.id);
              _selectedLectureIndex = 0;
              _lectureTitleControllers.clear();
              _editingLectureIndices.clear();
              _showPlanList = false;
            }),
          ),
        );
      }).toList(),
    );
  }

  // ── Right panel (shared desktop + mobile) ─────────────────────────────────

  Widget _buildRightPanel(LessonPlanModel? plan, {required bool isDesktop}) {
    if (plan == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_outlined, size: 40, color: AppTheme.textHint),
              Gap(12),
              Text('Select a plan to view it',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    final sessionRegex = RegExp(r'##\s*(?:Session|Lecture)\s*\d+[:\s]');
    final sections = plan.content.split(sessionRegex);
    final chapterIntro = sections[0];
    final lectures = sections.length > 1 ? sections.sublist(1) : <String>[];

    for (var i = 1; i <= lectures.length; i++) {
      if (!_lectureTitleControllers.containsKey(i)) {
        final title = _extractSessionTitle(plan.content, i) ?? 'Session $i';
        _lectureTitleControllers[i] = TextEditingController(text: title);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.topic,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                        overflow: TextOverflow.ellipsis),
                    Text('${plan.numLectures} sessions',
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              _ExportPdfButton(
                tooltip: 'Export as PDF',
                onExport: () => exportMarkdownToPdf(
                  markdownContent: plan.content,
                  fileName: plan.topic
                      .replaceAll(RegExp(r'[^\w\s-]'), '')
                      .trim()
                      .replaceAll(' ', '_'),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => _EditPlanScreen(plan: plan)),
                ).then((_) => _refreshPlans()),
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: const Text('Edit',
                    style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.brown,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6)),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Session tab bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: [
              _sessionTab('Overview', 0),
              ...List.generate(lectures.length,
                  (i) => _sessionTab('Session ${i + 1}', i + 1)),
            ],
          ),
        ),
        const Divider(height: 1),

        // Content area
        Padding(
          padding: const EdgeInsets.all(16),
          child: Builder(builder: (_) {
            if (_selectedLectureIndex == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (chapterIntro.trim().isNotEmpty)
                    MarkdownBody(
                      data: chapterIntro,
                      styleSheet: MarkdownStyleSheet(
                        h1: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                            color: AppTheme.brown),
                        p: const TextStyle(height: 1.6, fontSize: 14),
                      ),
                    ),
                  const Gap(12),
                  ...List.generate(lectures.length, (i) {
                    final sessionTitle =
                        _extractSessionTitle(plan.content, i + 1) ??
                            'Session ${i + 1}';
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedLectureIndex = i + 1;
                        _lectureTitleControllers.clear();
                        _editingLectureIndices.clear();
                      }),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.goldSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppTheme.brown
                                  .withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppTheme.brown,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12)),
                              ),
                            ),
                            const Gap(10),
                            Expanded(
                              child: Text(
                                'Session ${i + 1}: $sessionTitle',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppTheme.brown),
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 13, color: AppTheme.brown),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            }

            final idx = _selectedLectureIndex;
            if (lectures.isEmpty || idx - 1 >= lectures.length) {
              return const SizedBox();
            }
            final lectureBody = lectures[idx - 1];
            final controller = _lectureTitleControllers[idx];
            final titleText = controller?.text ??
                _extractSessionTitle(plan.content, idx) ??
                'Session $idx';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: controller != null
                          ? TextField(
                              controller: controller,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero),
                              onSubmitted: (v) =>
                                  _saveLectureTitle(idx, v),
                            )
                          : Text(titleText,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.save_rounded,
                          size: 18, color: AppTheme.brown),
                      tooltip: 'Save heading',
                      onPressed: () => _saveLectureTitle(
                          idx, controller?.text ?? titleText),
                      style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    ),
                  ],
                ),
                const Divider(),
                MarkdownBody(
                  data: lectureBody,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    h1: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: AppTheme.brown),
                    h2: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                    p: const TextStyle(height: 1.6, fontSize: 14),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _sessionTab(String label, int index) {
    final isSelected = _selectedLectureIndex == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedLectureIndex = index;
        _lectureTitleControllers.clear();
        _editingLectureIndices.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.brown : AppTheme.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected ? AppTheme.brown : AppTheme.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  // ── Feature icons ─────────────────────────────────────────────────────────

  Widget _buildFeatureIcons(bool isDesktop) {
    final features = [
      {
        'title': 'Lesson Planner',
        'sub': 'AI-generated plans',
        'icon': Icons.auto_stories_rounded,
        'color': AppTheme.brown,
        'bg': AppTheme.goldSurface,
        'screen': LessonPlannerScreen(grade: selectedGrade, subject: selectedSubject),
      },
      {
        'title': 'Worksheet',
        'sub': 'Practice sheets',
        'icon': Icons.assignment_rounded,
        'color': AppTheme.success,
        'bg': AppTheme.successLight,
        'screen': const WorksheetGeneratorScreen(),
      },
      {
        'title': 'Engagement',
        'sub': 'Boost class',
        'icon': Icons.celebration_rounded,
        'color': AppTheme.gold,
        'bg': AppTheme.goldSurface,
        'screen': const EngagementSuggestionScreen(),
      },
      {
        'title': 'Simplifier',
        'sub': 'Easy concepts',
        'icon': Icons.lightbulb_rounded,
        'color': AppTheme.info,
        'bg': AppTheme.infoLight,
        'screen': const ConceptSimplifierScreen(),
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isDesktop ? 4 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: isDesktop ? 1.5 : 2.0,
      ),
      itemCount: features.length,
      itemBuilder: (_, i) {
        final f = features[i];
        return _FeatureCard(
          title: f['title'] as String,
          subtitle: f['sub'] as String,
          icon: f['icon'] as IconData,
          color: f['color'] as Color,
          bg: f['bg'] as Color,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => f['screen'] as Widget),
          ).then((_) => _refreshPlans()),
        );
      },
    );
  }

  // ── Grade/subject grid ────────────────────────────────────────────────────

  Widget _buildGrid(
    String title,
    List<String> items,
    Function(String) onSelect, {
    required bool isDesktop,
    bool showBack = false,
    VoidCallback? onBack,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (showBack) ...[
              InkWell(
                onTap: onBack,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.goldSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.arrow_back_ios_rounded,
                      size: 15, color: AppTheme.brown),
                ),
              ),
              const Gap(12),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary)),
                Text(
                  showBack
                      ? 'Select your subject area'
                      : 'Select a grade to get started',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ],
        ),
        const Gap(18),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 4 : 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: isDesktop ? 3.5 : 2.6,
          ),
          itemCount: items.length,
          itemBuilder: (_, i) => FadeInTransition(
            child: _GridTile(
                label: items[i], onTap: () => onSelect(items[i])),
          ),
        ),
      ],
    );
  }

  // ── Breadcrumbs ───────────────────────────────────────────────────────────

  Widget _buildBreadcrumbs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              ref.read(planProvider.notifier).clearActivePlan();
              ref.read(shellProvider.notifier).clearLocation();
              setState(() {
                selectedSubject = null;
                _selectedLectureIndex = 0;
                _lectureTitleControllers.clear();
                _editingLectureIndices.clear();
                _showPlanList = true;
              });
            },
            child: Text(selectedGrade!,
                style: const TextStyle(
                    color: AppTheme.brown,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.chevron_right, size: 15, color: AppTheme.textHint),
          ),
          Text(selectedSubject!,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyPlanState() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LessonPlannerScreen(
                grade: selectedGrade, subject: selectedSubject)),
      ).then((_) => _refreshPlans()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 32),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: AppTheme.brown.withValues(alpha: 0.15), width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                  color: AppTheme.goldSurface, shape: BoxShape.circle),
              child: const Icon(Icons.add_rounded,
                  size: 30, color: AppTheme.brown),
            ),
            const Gap(16),
            const Text('No Lesson Plans Yet',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.textPrimary)),
            const Gap(8),
            Text(
              'No plans for $selectedGrade · $selectedSubject yet.\nTap to generate your first lesson plan.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                  fontSize: 13),
            ),
            const Gap(20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                  color: AppTheme.brown,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_stories_rounded,
                      color: Colors.white, size: 15),
                  Gap(8),
                  Text('Generate Plan',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Delete plan confirm ───────────────────────────────────────────────────

  void _confirmDeletePlan(LessonPlanModel plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Plan?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            'Permanently delete "${plan.topic}"? This cannot be undone.'),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          OutlinedButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          const Gap(8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(planProvider.notifier).deletePlan(plan.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted "${plan.topic}"')),
        );
        setState(() => _showPlanList = true);
      }
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String? _extractSessionTitle(String content, int index) {
    try {
      final regex = RegExp(
          r'##\s*(?:Session|Lecture)\s*' + index.toString() + r'(.*)',
          multiLine: true);
      final m = regex.firstMatch(content);
      if (m != null) {
        final raw = m.group(1)?.trim() ?? '';
        if (raw.isEmpty) return null;
        return raw.replaceFirst(RegExp(r'^[:\-\s]+'), '');
      }
    } catch (_) {}
    return null;
  }

  Future<void> _saveLectureTitle(int index, String newTitle) async {
    final plan = ref.read(planProvider).activePlan;
    if (plan == null) return;
    final pattern = RegExp(
        r'##\s*(?:Session|Lecture)\s*' + index.toString() + r'.*',
        multiLine: true);
    final replacement = '## Session $index: ${newTitle.trim()}';
    final updated = pattern.hasMatch(plan.content)
        ? plan.content.replaceFirst(pattern, replacement)
        : plan.content;
    await ref.read(planProvider.notifier).updatePlanContent(plan.id, updated);
    setState(() => _editingLectureIndices.remove(index));
  }
}

// ── Small reusable widgets ────────────────────────────────────────────────────

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _AppBarButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 19),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SectionLabel(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const Gap(6),
        Text(label,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _PlanListTile extends StatelessWidget {
  final LessonPlanModel plan;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _PlanListTile(
      {required this.plan,
      required this.isActive,
      required this.onTap,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      selected: isActive,
      selectedColor: AppTheme.brown,
      selectedTileColor: AppTheme.goldSurface,
      leading: Icon(
        Icons.description_outlined,
        color: isActive ? AppTheme.brown : AppTheme.textSecondary,
        size: 18,
      ),
      title: Text(plan.topic,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isActive ? FontWeight.w700 : FontWeight.w500,
              color: AppTheme.textPrimary)),
      subtitle: Text('${plan.numLectures} sessions',
          style:
              const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline_rounded,
            size: 16, color: AppTheme.danger),
        onPressed: onDelete,
        style: IconButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ),
      onTap: onTap,
    );
  }
}

class _FeatureCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _FeatureCard(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.color,
      required this.bg,
      required this.onTap});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -4.0 : 0.0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _hovered ? widget.color : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: _hovered ? widget.color : AppTheme.border),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: widget.color.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _hovered
                      ? Colors.white.withValues(alpha: 0.2)
                      : widget.bg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(widget.icon,
                    color: _hovered ? Colors.white : widget.color, size: 20),
              ),
              const Gap(8),
              Text(widget.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color:
                          _hovered ? Colors.white : AppTheme.textPrimary)),
              Text(widget.subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: _hovered
                          ? Colors.white70
                          : AppTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GridTile extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GridTile({required this.label, required this.onTap});

  @override
  State<_GridTile> createState() => _GridTileState();
}

class _GridTileState extends State<_GridTile> {
  bool _hovered = false;

  // Returns just the number if label is "Grade N", else null
  String? _gradeNumber(String label) {
    final match = RegExp(r'^Grade\s+(\d+)$').firstMatch(label.trim());
    return match?.group(1);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.identity()
            ..translate(0.0, _hovered ? -3.0 : 0.0),
          decoration: BoxDecoration(
            color: _hovered ? AppTheme.brown : AppTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _hovered ? AppTheme.brown : AppTheme.border),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                        color: AppTheme.brown.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 3))
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _hovered
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppTheme.goldSurface,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Icon(Icons.class_rounded,
                      size: 14,
                      color: _hovered ? Colors.white : AppTheme.brown),
                ),
                const Gap(10),
                Flexible(
                  child: _gradeNumber(widget.label) != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _gradeNumber(widget.label)!,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: _hovered ? Colors.white : AppTheme.brown,
                              ),
                            ),
                            Text(
                              'Grade',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: _hovered ? Colors.white70 : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        )
                      : Text(
                          widget.label,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _hovered ? Colors.white : AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Edit Plan Screen ──────────────────────────────────────────────────────────

class _EditSection {
  final String heading;
  String body;
  _EditSection({required this.heading, required this.body});
}

List<_EditSection> _parseEditSections(String content) {
  final lines = content.split('\n');
  final sections = <_EditSection>[];
  String? currentHeading;
  final bodyLines = <String>[];
  for (final line in lines) {
    if (line.startsWith('## ') ||
        (line.startsWith('# ') &&
            sections.isEmpty &&
            currentHeading == null)) {
      if (currentHeading != null || bodyLines.isNotEmpty) {
        sections.add(_EditSection(
            heading: currentHeading ?? '',
            body: bodyLines.join('\n').trim()));
        bodyLines.clear();
      }
      currentHeading = line;
    } else {
      bodyLines.add(line);
    }
  }
  if (currentHeading != null || bodyLines.isNotEmpty) {
    sections.add(_EditSection(
        heading: currentHeading ?? '', body: bodyLines.join('\n').trim()));
  }
  return sections;
}

String _rebuildEditContent(List<_EditSection> sections) {
  return sections.map((s) {
    final parts = <String>[];
    if (s.heading.isNotEmpty) parts.add(s.heading);
    if (s.body.isNotEmpty) parts.add(s.body);
    return parts.join('\n\n');
  }).join('\n\n');
}

class _EditPlanScreen extends ConsumerStatefulWidget {
  final LessonPlanModel plan;
  const _EditPlanScreen({required this.plan});

  @override
  ConsumerState<_EditPlanScreen> createState() => _EditPlanScreenState();
}

class _EditPlanScreenState extends ConsumerState<_EditPlanScreen> {
  late final TextEditingController _ctrl;
  late List<_EditSection> _sections;
  bool _saving = false;
  bool _rawEdit = false;
  int? _selectedSectionIndex;
  bool _isSectionRegenerating = false;
  final _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.plan.content);
    _sections = _parseEditSections(widget.plan.content);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final contentToSave =
        _rawEdit ? _ctrl.text : _rebuildEditContent(_sections);
    setState(() => _saving = true);
    await ref
        .read(planProvider.notifier)
        .updatePlanContent(widget.plan.id, contentToSave);
    setState(() => _saving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Plan saved ✓'),
            backgroundColor: AppTheme.secondary),
      );
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
      _selectedSectionIndex = null;
    });
    try {
      final res = await _apiService.regenerate(
        feature: 'lesson',
        originalContent: sectionText,
        instruction: instruction,
        planId: widget.plan.id,
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
          _ctrl.text = _rebuildEditContent(_sections);
        });
        await ref
            .read(planProvider.notifier)
            .updatePlanContent(widget.plan.id, _ctrl.text);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                Gap(8),
                Text('Section regenerated & saved!'),
              ]),
              backgroundColor: Colors.green.shade600,
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
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.plan.topic,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${widget.plan.grade} · ${widget.plan.subject}',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              if (_rawEdit) {
                setState(() {
                  _sections = _parseEditSections(_ctrl.text);
                  _rawEdit = false;
                });
              } else {
                _ctrl.text = _rebuildEditContent(_sections);
                setState(() => _rawEdit = true);
              }
            },
            icon: Icon(
                _rawEdit
                    ? Icons.view_agenda_outlined
                    : Icons.code_rounded,
                size: 15),
            label: Text(_rawEdit ? 'Section View' : 'Raw Edit',
                style: const TextStyle(fontSize: 13)),
          ),
          const Gap(4),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
          ),
          const Gap(12),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(color: AppTheme.border, height: 1)),
      ),
      body: _isSectionRegenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                      strokeWidth: 4, color: AppTheme.brown),
                  Gap(20),
                  Text('Regenerating section…',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.brown)),
                ],
              ),
            )
          : _rawEdit
              ? _buildRawEditor()
              : _buildSectionView(),
    );
  }

  Widget _buildRawEditor() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _ctrl,
        maxLines: null,
        expands: true,
        style: const TextStyle(
            fontFamily: 'monospace', fontSize: 13, height: 1.5),
        decoration: InputDecoration(
          hintText: 'Edit lesson plan content here…',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }

  Widget _buildSectionView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.goldSurface,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.brown.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.touch_app_rounded,
                    color: AppTheme.brown, size: 16),
                Gap(8),
                Expanded(
                  child: Text(
                    'Tap any section to select, then regenerate just that part.',
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
                              color: AppTheme.brown.withValues(alpha: 0.1),
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
                        styleSheet: MarkdownStyleSheet(
                          h1: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: AppTheme.brown),
                          h2: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                          p: const TextStyle(height: 1.6, fontSize: 14),
                        ),
                      ),
                    ),
                    if (isSelected)
                      Container(
                        decoration: BoxDecoration(
                          color: AppTheme.goldSurface,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(14),
                            bottomRight: Radius.circular(14),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
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
    );
  }
}

// ── Export PDF button ─────────────────────────────────────────────────────────

class _ExportPdfButton extends StatefulWidget {
  final Future<void> Function() onExport;
  final String tooltip;

  const _ExportPdfButton({required this.onExport, required this.tooltip});

  @override
  State<_ExportPdfButton> createState() => _ExportPdfButtonState();
}

class _ExportPdfButtonState extends State<_ExportPdfButton> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: TextButton.icon(
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
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.accent))
            : const Icon(Icons.picture_as_pdf_rounded,
                size: 15, color: AppTheme.accent),
        label: Text(
          _exporting ? 'Exporting…' : 'PDF',
          style: const TextStyle(color: AppTheme.accent, fontSize: 13),
        ),
        style: TextButton.styleFrom(
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
      ),
    );
  }
}
