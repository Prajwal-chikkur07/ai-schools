import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/core/components/sprout_components.dart';
import 'package:teacher_ai/features/auth/signup_screen.dart';
import 'package:teacher_ai/features/shell/app_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading       = false;
  bool _obscurePassword = true;

  void _handleLogin() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const AppShell(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          if (isWide) {
            return _buildWideLayout();
          }
          return _buildNarrowLayout();
        },
      ),
    );
  }

  // ── Wide: split left panel + right form ──────────────────────────────────
  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left panel – brand/illustration
        Expanded(
          flex: 5,
          child: Container(
            color: AppTheme.brown,
            child: Stack(
              children: [
                // Organic leaf decorators
                const Positioned(top: -40, right: -40,
                  child: LeafDecorator(size: 280, color: AppTheme.gold, opacity: 0.08)),
                const Positioned(bottom: -60, left: -30,
                  child: LeafDecorator(size: 240, color: Colors.white, opacity: 0.05)),
                const Positioned(top: 200, left: 40,
                  child: LeafDecorator(size: 80, color: AppTheme.gold, opacity: 0.12)),

                // Content
                Padding(
                  padding: const EdgeInsets.all(56),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo row
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('AI Schools',
                            style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800,
                              color: Colors.white, letterSpacing: -0.5,
                            ),
                          ),
                          Text('Teacher Assistant Platform',
                            style: TextStyle(fontSize: 12, color: AppTheme.navTextMuted),
                          ),
                        ],
                      ),

                      const Spacer(),

                      // Hero copy
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('✦',
                              style: TextStyle(fontSize: 24, color: AppTheme.gold)),
                            Gap(12),
                            Text(
                              'Empower your\nteaching with AI',
                              style: TextStyle(
                                fontSize: 32, fontWeight: FontWeight.w800,
                                color: Colors.white, height: 1.2, letterSpacing: -0.5,
                              ),
                            ),
                            Gap(12),
                            Text(
                              'Generate lesson plans, worksheets, and\nengagement ideas in seconds.',
                              style: TextStyle(
                                fontSize: 15, color: AppTheme.navTextMuted, height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Gap(32),

                      // Feature pills
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _featurePill(Icons.description_outlined, 'Lesson Planner'),
                          _featurePill(Icons.grid_view_rounded, 'Worksheets'),
                          _featurePill(Icons.lightbulb_outline, 'Engagement'),
                          _featurePill(Icons.auto_awesome, 'AI Assistant'),
                        ],
                      ),

                      const Gap(48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right panel – form
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: _buildForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _featurePill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.gold, size: 15),
          const Gap(6),
          Text(label,
            style: const TextStyle(
              fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Narrow: centred card ─────────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(36),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.border),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brown.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: _buildForm(),
        ),
      ),
    );
  }

  // ── Shared form ──────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Brand mark
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Schools',
              style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w800,
                color: AppTheme.brown, letterSpacing: -0.3,
              ),
            ),
            Text('Teacher Assistant',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
        const Gap(32),

        // Heading
        const Text('Welcome back',
          style: TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800,
            color: AppTheme.brown, letterSpacing: -0.5,
          ),
        ),
        const Gap(4),
        const Text('Sign in to your account to continue',
          style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
        ),
        const Gap(32),

        // Email field
        const Text('Email',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const Gap(8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'you@school.edu',
            prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppTheme.textSecondary),
          ),
        ),
        const Gap(18),

        // Password field
        const Text('Password',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const Gap(8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: '••••••••',
            prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 18, color: AppTheme.textSecondary,
              ),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
        ),
        const Gap(8),

        // Forgot password
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Forgot password?',
              style: TextStyle(fontSize: 13, color: AppTheme.gold, fontWeight: FontWeight.w600)),
          ),
        ),
        const Gap(24),

        // Sign In button (gold)
        SizedBox(
          width: double.infinity,
          child: GoldButton(
            label: 'Sign In',
            icon: Icons.arrow_forward_rounded,
            loading: _isLoading,
            onTap: _handleLogin,
          ),
        ),
        const Gap(20),

        // Divider
        const Row(
          children: [
            Expanded(child: Divider(color: AppTheme.border)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('or', style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
            ),
            Expanded(child: Divider(color: AppTheme.border)),
          ],
        ),
        const Gap(20),

        // Sign up link
        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Don't have an account? ",
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignupScreen()),
                ),
                child: const Text('Sign up',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppTheme.brown,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.gold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Gap(24),

        // Footer
        const Center(
          child: Text('AI Schools © 2026',
            style: TextStyle(fontSize: 11, color: AppTheme.textHint)),
        ),
      ],
    );
  }
}
