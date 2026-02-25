import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Editable fields
  final _nameController    = TextEditingController(text: 'Sarah Johnson');
  final _idController      = TextEditingController(text: 'TCH-2025-001');
  final _emailController   = TextEditingController(text: 'sarah@school.edu');
  final _phoneController   = TextEditingController(text: '+1 (555) 012-3456');
  final _schoolController  = TextEditingController(text: 'Greenwood High School');
  final _deptController    = TextEditingController(text: 'Science & Mathematics');
  final _bioController     = TextEditingController(
      text: 'Passionate educator with 8+ years of experience in secondary education.');

  bool _isEditing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _deptController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _toggleEdit() {
    setState(() => _isEditing = !_isEditing);
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _toggleEdit,
              icon: Icon(_isEditing ? Icons.check_rounded : Icons.edit_outlined, size: 18),
              label: Text(_isEditing ? 'Save' : 'Edit'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.brown),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar card ─────────────────────────────────────────
                _Card(
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: AppTheme.goldSurface,
                            child: const Text(
                              'SJ',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.brown,
                              ),
                            ),
                          ),
                          if (_isEditing)
                            Positioned(
                              bottom: 0, right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.brown,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt_outlined,
                                    color: Colors.white, size: 14),
                              ),
                            ),
                        ],
                      ),
                      const Gap(16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nameController.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const Gap(2),
                            Text(
                              _idController.text,
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary),
                            ),
                            const Gap(6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.successLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Active Teacher',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.success),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),

                // ── Personal Info ────────────────────────────────────────
                _SectionTitle('Personal Information'),
                const Gap(10),
                _Card(
                  child: Column(
                    children: [
                      _Field(
                        label: 'Full Name',
                        icon: Icons.person_outline,
                        controller: _nameController,
                        enabled: _isEditing,
                      ),
                      _Divider(),
                      _Field(
                        label: 'Teacher ID',
                        icon: Icons.badge_outlined,
                        controller: _idController,
                        enabled: false, // ID is read-only always
                      ),
                      _Divider(),
                      _Field(
                        label: 'Email Address',
                        icon: Icons.email_outlined,
                        controller: _emailController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      _Divider(),
                      _Field(
                        label: 'Phone Number',
                        icon: Icons.phone_outlined,
                        controller: _phoneController,
                        enabled: _isEditing,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
                const Gap(16),

                // ── School Info ──────────────────────────────────────────
                _SectionTitle('School Information'),
                const Gap(10),
                _Card(
                  child: Column(
                    children: [
                      _Field(
                        label: 'School Name',
                        icon: Icons.school_outlined,
                        controller: _schoolController,
                        enabled: _isEditing,
                      ),
                      _Divider(),
                      _Field(
                        label: 'Department',
                        icon: Icons.category_outlined,
                        controller: _deptController,
                        enabled: _isEditing,
                      ),
                    ],
                  ),
                ),
                const Gap(16),

                // ── Bio ──────────────────────────────────────────────────
                _SectionTitle('Bio'),
                const Gap(10),
                _Card(
                  child: _isEditing
                      ? TextField(
                          controller: _bioController,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              height: 1.6),
                        )
                      : Text(
                          _bioController.text,
                          style: const TextStyle(
                              fontSize: 14,
                              color: AppTheme.textPrimary,
                              height: 1.6),
                        ),
                ),
                const Gap(16),

                // ── Danger zone ──────────────────────────────────────────
                _SectionTitle('Account'),
                const Gap(10),
                _Card(
                  child: Column(
                    children: [
                      _ActionRow(
                        icon: Icons.lock_outline,
                        label: 'Change Password',
                        onTap: () => _showChangePasswordDialog(context),
                      ),
                      _Divider(),
                      _ActionRow(
                        icon: Icons.logout_rounded,
                        label: 'Sign Out',
                        color: AppTheme.danger,
                        onTap: () => _confirmSignOut(context),
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

  void _showChangePasswordDialog(BuildContext context) {
    final current = TextEditingController();
    final next    = TextEditingController();
    final confirm = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const Gap(12),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const Gap(12),
            TextField(
              controller: confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully.')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Sign Out'),
          ),
        ],
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
        padding: const EdgeInsets.all(16),
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
  Widget build(BuildContext context) => const Divider(height: 20, color: AppTheme.border);
}

class _Field extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool enabled;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.icon,
    required this.controller,
    this.enabled = true,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.2)),
              const Gap(2),
              enabled
                  ? TextField(
                      controller: controller,
                      keyboardType: keyboardType,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.brown, width: 1.5),
                        ),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        fillColor: Colors.transparent,
                        filled: false,
                      ),
                    )
                  : Text(
                      controller.text,
                      style: TextStyle(
                          fontSize: 14,
                          color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary),
                    ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = AppTheme.textPrimary,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const Gap(12),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, size: 18, color: color.withValues(alpha: 0.5)),
            ],
          ),
        ),
      );
}

