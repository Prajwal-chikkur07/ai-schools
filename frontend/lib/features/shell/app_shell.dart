import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_ai/features/dashboard/dashboard_screen.dart';

/// Application shell — renders the dashboard directly with no nav rail.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const DashboardScreen();
  }
}
