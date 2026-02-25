import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:teacher_ai/core/api/api_service.dart';
import 'package:teacher_ai/core/components/sprout_components.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/providers/plan_provider.dart';
import 'package:teacher_ai/features/engagement/engagement_screen.dart';

class ConceptSimplifierScreen extends ConsumerStatefulWidget {
  const ConceptSimplifierScreen({super.key});

  @override
  ConsumerState<ConceptSimplifierScreen> createState() => _ConceptSimplifierScreenState();
}

class _ConceptSimplifierScreenState extends ConsumerState<ConceptSimplifierScreen> {
  final _apiService = ApiService();
  final _inputController = TextEditingController();
  final _regenController = TextEditingController();
  
  bool _isLoading = false;
  String _generatedContent = "";
  String _originalInput = "";

  @override
  void initState() {
    super.initState();
    final activeTopic = ref.read(planProvider).topic;
    if (activeTopic != null) {
      _inputController.text = activeTopic;
    }
  }

  Future<void> _generate() async {
    final activePlanId = ref.read(planProvider).activePlanId;
    setState(() {
      _isLoading = true;
      _originalInput = _inputController.text;
    });
    try {
      final res = await _apiService.simplifyConcept(_inputController.text, planId: activePlanId);
      if (res['success']) {
        setState(() => _generatedContent = res['content']);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRegeneration() async {
    final activePlanId = ref.read(planProvider).activePlanId;
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.regenerate(
        feature: "simplifier",
        originalContent: _generatedContent,
        instruction: _regenController.text,
        planId: activePlanId,
      );
      if (res['success']) {
        setState(() {
          _generatedContent = res['content'];
          _regenController.clear();
        });
        Navigator.pop(context); // Close the bottom sheet
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
          tooltip: 'Engagement Suggestions',
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EngagementSuggestionScreen())),
        ),
        title: const Text('Concept Simplifier', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: AppTheme.border, height: 1)),
      ),
      body: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_generatedContent.isNotEmpty) return _buildOutput();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FadeInTransition(
            child: Text('Explain Like I’m Five', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          ),
          const Gap(8),
          const Text('Enter a complex topic or text to simplify for students.', style: TextStyle(color: Colors.grey)),
          const Gap(32),
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 15,
              decoration: InputDecoration(
                hintText: 'Paste a complex scientific concept, historical event, or mathematical theorem...',
                fillColor: Colors.purple.withOpacity(0.02),
              ),
            ),
          ),
          const Gap(24),
          ElevatedButton(
            onPressed: _inputController.text.isEmpty ? null : _generate,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Simplify Now'),
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
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Original:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple)),
                      Text(_originalInput, style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic)),
                      const Divider(height: 32),
                      MarkdownBody(data: _generatedContent),
                    ],
                  ),
                ),
              ],
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
          Expanded(child: OutlinedButton(onPressed: () => _showRegenSheet(), child: const Text('Refine / Regenerate'))),
          const Gap(16),
          Expanded(child: ElevatedButton(onPressed: () {}, child: const Text('Save Explanation'))),
        ],
      ),
    );
  }

  void _showRegenSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('What would you like to change?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Gap(16),
            TextField(
              controller: _regenController,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'e.g. Make it even simpler, use more analogies...'),
              maxLines: 3,
            ),
            const Gap(24),
            ElevatedButton(onPressed: _handleRegeneration, child: const Text('Update Content')),
            const Gap(32),
          ],
        ),
      ),
    );
  }
}
