import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';
import 'package:teacher_ai/features/settings/manage_grades_subjects_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _emailDigest          = false;
  bool _autoSave             = true;
  String _language           = 'English';
  String _theme              = 'Light';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Curriculum ───────────────────────────────────────────
                _SectionTitle('Curriculum'),
                const Gap(10),
                _Card(
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.tune_rounded,
                        iconColor: AppTheme.brown,
                        iconBg: AppTheme.goldSurface,
                        label: 'Manage Grades & Subjects',
                        subtitle: 'Add, remove or reorder grades and subjects',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ManageGradesSubjectsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(20),

                // ── Preferences ──────────────────────────────────────────
                _SectionTitle('Preferences'),
                const Gap(10),
                _Card(
                  child: Column(
                    children: [
                      _DropdownRow(
                        icon: Icons.language_rounded,
                        iconColor: AppTheme.success,
                        iconBg: AppTheme.successLight,
                        label: 'Language',
                        value: _language,
                        options: const ['English', 'Spanish', 'French', 'Hindi'],
                        onChanged: (v) => setState(() => _language = v!),
                      ),
                      _Divider(),
                      _DropdownRow(
                        icon: Icons.palette_outlined,
                        iconColor: AppTheme.purple,
                        iconBg: AppTheme.purpleLight,
                        label: 'App Theme',
                        value: _theme,
                        options: const ['Light', 'Dark', 'System'],
                        onChanged: (v) => setState(() => _theme = v!),
                      ),
                      _Divider(),
                      _ToggleRow(
                        icon: Icons.save_outlined,
                        iconColor: AppTheme.gold,
                        iconBg: AppTheme.goldSurface,
                        label: 'Auto-save Plans',
                        subtitle: 'Automatically save lesson plans as you work',
                        value: _autoSave,
                        onChanged: (v) => setState(() => _autoSave = v),
                      ),
                    ],
                  ),
                ),
                const Gap(20),

                // ── Notifications ────────────────────────────────────────
                _SectionTitle('Notifications'),
                const Gap(10),
                _Card(
                  child: Column(
                    children: [
                      _ToggleRow(
                        icon: Icons.notifications_outlined,
                        iconColor: AppTheme.brown,
                        iconBg: AppTheme.goldSurface,
                        label: 'Push Notifications',
                        subtitle: 'Receive in-app alerts and reminders',
                        value: _notificationsEnabled,
                        onChanged: (v) => setState(() => _notificationsEnabled = v),
                      ),
                      _Divider(),
                      _ToggleRow(
                        icon: Icons.email_outlined,
                        iconColor: AppTheme.success,
                        iconBg: AppTheme.successLight,
                        label: 'Weekly Email Digest',
                        subtitle: 'Summary of your activity every week',
                        value: _emailDigest,
                        onChanged: (v) => setState(() => _emailDigest = v),
                      ),
                    ],
                  ),
                ),
                const Gap(20),

                // ── About ────────────────────────────────────────────────
                _SectionTitle('About'),
                const Gap(10),
                _Card(
                  child: Column(
                    children: [
                      _NavRow(
                        icon: Icons.info_outline_rounded,
                        iconColor: AppTheme.textSecondary,
                        iconBg: const Color(0xFFF1F5F9),
                        label: 'App Version',
                        subtitle: 'Sprout AI v1.0.0',
                        onTap: null,
                        showArrow: false,
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.description_outlined,
                        iconColor: AppTheme.textSecondary,
                        iconBg: const Color(0xFFF1F5F9),
                        label: 'Terms of Service',
                        subtitle: 'Read our terms and conditions',
                        onTap: () {},
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.privacy_tip_outlined,
                        iconColor: AppTheme.textSecondary,
                        iconBg: const Color(0xFFF1F5F9),
                        label: 'Privacy Policy',
                        subtitle: 'How we handle your data',
                        onTap: () {},
                      ),
                      _Divider(),
                      _NavRow(
                        icon: Icons.help_outline_rounded,
                        iconColor: AppTheme.textSecondary,
                        iconBg: const Color(0xFFF1F5F9),
                        label: 'Help & Support',
                        subtitle: 'FAQs and contact support',
                        onTap: () {},
                      ),
                    ],
                  ),
                ),
                const Gap(32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
        ),
        child: child,
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
            letterSpacing: 0.3),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: AppTheme.border);
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showArrow;

  const _NavRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const Gap(14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.textPrimary)),
                    const Gap(1),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (showArrow)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppTheme.textHint),
            ],
          ),
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const Gap(14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary)),
                  const Gap(1),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.brown,
            ),
          ],
        ),
      );
}

class _DropdownRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _DropdownRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const Gap(14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary)),
            ),
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                items: options
                    .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                    .toList(),
                onChanged: onChanged,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500),
                icon: const Icon(Icons.expand_more_rounded,
                    size: 18, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );
}
