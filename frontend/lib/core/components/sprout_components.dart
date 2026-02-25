import 'package:flutter/material.dart';
import 'package:teacher_ai/core/constants/app_theme.dart';

// ── Seedling Labs / Sprout AI Logo ────────────────────────────────────────────

/// The Sprout AI logo: gold ring with dark-brown bird silhouette on cream bg.
class SeedlingLabsLogo extends StatelessWidget {
  final double size;
  const SeedlingLabsLogo({super.key, this.size = 36});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _SeedlingLogosPainter()),
    );
  }
}

class _SeedlingLogosPainter extends CustomPainter {
  static const _cream = Color(0xFFF5EFE0);
  static const _gold  = Color(0xFFC8961E);
  static const _brown = Color(0xFF3D1F0D);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = _cream);
    canvas.drawCircle(
      Offset(cx, cy), r,
      Paint()
        ..color = _gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * 0.09,
    );

    final scale = size.width / 100.0;
    final path  = Path();
    path.moveTo(22 * scale, 62 * scale);
    path.cubicTo(30 * scale, 72 * scale, 55 * scale, 68 * scale, 72 * scale, 42 * scale);
    path.cubicTo(78 * scale, 32 * scale, 68 * scale, 22 * scale, 60 * scale, 28 * scale);
    path.cubicTo(52 * scale, 34 * scale, 38 * scale, 52 * scale, 32 * scale, 44 * scale);
    path.cubicTo(26 * scale, 36 * scale, 32 * scale, 22 * scale, 44 * scale, 24 * scale);
    path.cubicTo(50 * scale, 22 * scale, 38 * scale, 10 * scale, 25 * scale, 20 * scale);
    path.cubicTo(14 * scale, 28 * scale, 12 * scale, 50 * scale, 22 * scale, 62 * scale);
    path.close();

    canvas.drawPath(path, Paint()..color = _brown..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Fade-in Transition ────────────────────────────────────────────────────────

class FadeInTransition extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double delay;

  const FadeInTransition({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.delay = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOut,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}

// ── Premium Sprout Card ───────────────────────────────────────────────────────

/// A hoverable card with soft lift + gold border glow on hover.
class SproutCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color? color;

  const SproutCard({super.key, required this.child, required this.onTap, this.color});

  @override
  State<SproutCard> createState() => _SproutCardState();
}

class _SproutCardState extends State<SproutCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit:  (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.identity()..translate(0, _isHovered ? -4.0 : 0.0),
        decoration: BoxDecoration(
          color: widget.color ?? AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isHovered ? AppTheme.gold.withOpacity(0.6) : AppTheme.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: _isHovered
              ? [
                  BoxShadow(
                    color: AppTheme.gold.withOpacity(0.12),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppTheme.brown.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            splashColor: AppTheme.gold.withOpacity(0.08),
            highlightColor: Colors.transparent,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// ── Shimmer Loader ───────────────────────────────────────────────────────────

class ShimmerLoader extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoader({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              AppTheme.surfaceAlt,
              AppTheme.border.withOpacity(0.5),
              AppTheme.surfaceAlt,
            ],
            stops: [0.0, _controller.value, 1.0],
          ),
        ),
      ),
    );
  }
}

// ── Premium Stat Card ─────────────────────────────────────────────────────────

/// A metric card with a gold accent value, icon, and optional progress bar.
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final double? progress; // 0.0–1.0, null hides the bar

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor = AppTheme.gold,
    this.iconBg    = AppTheme.goldSurface,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brown.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppTheme.brown,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: AppTheme.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.gold),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Gold Button ───────────────────────────────────────────────────────────────

class GoldButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool loading;
  final double? width;

  const GoldButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.loading = false,
    this.width,
  });

  @override
  State<GoldButton> createState() => _GoldButtonState();
}

class _GoldButtonState extends State<GoldButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: 48,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _hovered
                ? [const Color(0xFFE8B520), AppTheme.gold]
                : [AppTheme.gold, const Color(0xFFC49010)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: AppTheme.gold.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppTheme.gold.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: widget.loading ? null : widget.onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: Colors.white.withOpacity(0.15),
            highlightColor: Colors.transparent,
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.brown,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: AppTheme.brownDark, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: AppTheme.brownDark,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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
}

// ── Section Header ────────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.brown,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Organic Leaf Decorator ────────────────────────────────────────────────────

/// Subtle decorative shape inspired by organic leaf/sprout forms.
class LeafDecorator extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const LeafDecorator({
    super.key,
    this.size = 120,
    this.color = AppTheme.gold,
    this.opacity = 0.07,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LeafPainter(color: color.withOpacity(opacity)),
      ),
    );
  }
}

class _LeafPainter extends CustomPainter {
  final Color color;
  const _LeafPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;
    // Organic leaf shape
    path.moveTo(w * 0.5, h * 0.05);
    path.cubicTo(w * 0.95, h * 0.1, w * 1.0, h * 0.6, w * 0.5, h * 0.98);
    path.cubicTo(w * 0.0,  h * 0.6, w * 0.05, h * 0.1, w * 0.5, h * 0.05);
    path.close();
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ── Nav Rail Item ─────────────────────────────────────────────────────────────

class NavRailItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool collapsed;

  const NavRailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.collapsed = false,
  });

  @override
  State<NavRailItem> createState() => _NavRailItemState();
}

class _NavRailItemState extends State<NavRailItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit:  (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.gold.withOpacity(0.18)
                : _hovered
                    ? Colors.white.withOpacity(0.07)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: isActive
                ? Border.all(color: AppTheme.gold.withOpacity(0.4), width: 1)
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 20,
                color: isActive ? AppTheme.gold : AppTheme.navTextMuted,
              ),
              if (!widget.collapsed) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      color: isActive ? AppTheme.gold : AppTheme.navTextMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isActive)
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
