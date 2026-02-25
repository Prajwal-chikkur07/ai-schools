import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:teacher_ai/core/api/api_service.dart';
import 'package:teacher_ai/core/components/sprout_components.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/providers/plan_provider.dart';
import 'package:teacher_ai/features/worksheet_generator/worksheet_generator_screen.dart';
import 'package:teacher_ai/features/concept_simplifier/concept_simplifier_screen.dart';

class EngagementSuggestionScreen extends ConsumerStatefulWidget {
  const EngagementSuggestionScreen({super.key});

  @override
  ConsumerState<EngagementSuggestionScreen> createState() => _EngagementSuggestionScreenState();
}

class _EngagementSuggestionScreenState extends ConsumerState<EngagementSuggestionScreen> {
  final _apiService = ApiService();
  final _topicController = TextEditingController();
  
  String _selectedType = "Icebreaker";
  bool _isLoading = false;
  String _generatedContent = "";

  final List<Map<String, dynamic>> _types = [
    {'name': 'Icebreaker', 'icon': Icons.waving_hand_outlined},
    {'name': 'Quiz', 'icon': Icons.quiz_outlined},
    {'name': 'Activities', 'icon': Icons.sports_esports_outlined},
    {'name': 'Discussion', 'icon': Icons.forum_outlined},
  ];

  @override
  void initState() {
    super.initState();
    final activeTopic = ref.read(planProvider).topic;
    if (activeTopic != null) {
      _topicController.text = activeTopic;
    }
  }

  Future<void> _generate() async {
    final activePlan = ref.read(planProvider).activePlanId;
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.generateEngagement(
        topic: _topicController.text,
        type: _selectedType,
        planId: activePlan,
      );
      if (res['success']) {
        setState(() => _generatedContent = res['content']);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          tooltip: 'Worksheet Generator',
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const WorksheetGeneratorScreen())),
        ),
        title: const Text('Engagement Suggestions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18),
              tooltip: 'Concept Simplifier',
              style: IconButton.styleFrom(backgroundColor: AppTheme.goldSurface, foregroundColor: AppTheme.gold),
              onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ConceptSimplifierScreen())),
            ),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AppTheme.border, height: 1)),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_generatedContent.isNotEmpty) return _buildOutput();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeInTransition(
            child: Text('Boost Class Participation', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const Gap(32),
          
          const Text('Topic', style: TextStyle(fontWeight: FontWeight.bold)),
          const Gap(8),
          TextField(controller: _topicController, decoration: const InputDecoration(hintText: 'e.g. Solar System')),

          const Gap(32),
          const Text('Engagement Type', style: TextStyle(fontWeight: FontWeight.bold)),
          const Gap(16),
          GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: _types.map((type) => GestureDetector(
              onTap: () => setState(() => _selectedType = type['name']),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: _selectedType == type['name'] ? Colors.orange.shade50 : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _selectedType == type['name'] ? Colors.orange : Colors.grey.shade200),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(type['icon'], color: _selectedType == type['name'] ? Colors.orange : Colors.grey),
                    const Gap(8),
                    Text(type['name'], style: TextStyle(fontWeight: FontWeight.bold, color: _selectedType == type['name'] ? Colors.orange : Colors.grey)),
                  ],
                ),
              ),
            )).toList(),
          ),

          const Gap(48),
          ElevatedButton(
            onPressed: _topicController.text.isEmpty ? null : _generate,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Get Suggestions'),
          ),
        ],
      ),
    );
  }

  Widget _buildOutput() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: FadeInTransition(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: MarkdownBody(data: _generatedContent),
              ),
            ),
          ),
        ),
        _buildActionBar(),
      ],
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _generatedContent = ""), child: const Text('Try Another'))),
          const Gap(16),
          Expanded(child: ElevatedButton(onPressed: () {}, child: const Text('Save to My List'))),
        ],
      ),
    );
  }
}
