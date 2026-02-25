import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/features/auth/login_screen.dart';

void main() {
  runApp(const ProviderScope(child: SproutAIApp()));
}

class SproutAIApp extends StatelessWidget {
  const SproutAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sprout AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}
