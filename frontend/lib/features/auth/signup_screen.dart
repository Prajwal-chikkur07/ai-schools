import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/features/shell/app_shell.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController     = TextEditingController();
  final _idController       = TextEditingController();
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController  = TextEditingController();

  bool _isLoading        = false;
  bool _obscurePassword  = true;
  bool _obscureConfirm   = true;
  String? _error;

  void _handleSignup() async {
    setState(() => _error = null);

    if (_nameController.text.trim().isEmpty ||
        _idController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo + Brand
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.goldSurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.school_rounded, color: AppTheme.brown, size: 24),
                    ),
                    const Gap(12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sprout AI',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        Text('Teacher Assistant',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ],
                ),
                const Gap(32),

                // Heading
                const Text('Create account',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const Gap(4),
                const Text('Register as a teacher to get started',
                    style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                const Gap(28),

                // Error banner
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
                  ),
                  const Gap(20),
                ],

                // Full Name
                _Label('Full Name'),
                const Gap(8),
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Sarah Johnson',
                    prefixIcon: Icon(Icons.person_outline, size: 18, color: AppTheme.textSecondary),
                  ),
                ),
                const Gap(16),

                // Teacher ID
                _Label('Teacher ID'),
                const Gap(8),
                TextField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. TCH-2025-001',
                    prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AppTheme.textSecondary),
                  ),
                ),
                const Gap(16),

                // Email
                _Label('Email'),
                const Gap(8),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'you@school.edu',
                    prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppTheme.textSecondary),
                  ),
                ),
                const Gap(16),

                // Password
                _Label('Password'),
                const Gap(8),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Min. 8 characters',
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
                const Gap(16),

                // Confirm Password
                _Label('Confirm Password'),
                const Gap(8),
                TextField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    hintText: 'Re-enter your password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        size: 18, color: AppTheme.textSecondary,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                ),
                const Gap(28),

                // Create Account Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSignup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Create Account'),
                  ),
                ),
                const Gap(20),

                // Back to login
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Already have an account? ',
                          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text('Sign in',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.brown)),
                      ),
                    ],
                  ),
                ),
                const Gap(20),

                const Center(
                  child: Text('Sprout AI © 2025',
                      style: TextStyle(fontSize: 12, color: AppTheme.textHint)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
      );
}
