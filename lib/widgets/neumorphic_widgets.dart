/// AURA Neumorphic Widgets
/// Reusable soft-UI components for the therapy app

import 'package:flutter/material.dart';
import '../theme/aura_theme.dart';

/// Neumorphic Button with soft shadows
class NeumorphicButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final double width;
  final double height;
  final double borderRadius;
  final EdgeInsets padding;

  const NeumorphicButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.width = double.infinity,
    this.height = 60,
    this.borderRadius = AuraTheme.radiusMedium,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<NeumorphicButton> createState() => _NeumorphicButtonState();
}

class _NeumorphicButtonState extends State<NeumorphicButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width,
        height: widget.height,
        padding: widget.padding,
        decoration: neumorphicDecoration(
          color: widget.color ?? AuraTheme.backgroundWhite,
          radius: widget.borderRadius,
          isPressed: _isPressed,
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

/// Neumorphic Card container
class NeumorphicCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final double borderRadius;
  final EdgeInsets padding;
  final EdgeInsets margin;

  const NeumorphicCard({
    super.key,
    required this.child,
    this.color,
    this.borderRadius = AuraTheme.radiusMedium,
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: neumorphicDecoration(
        color: color ?? AuraTheme.backgroundWhite,
        radius: borderRadius,
      ),
      child: child,
    );
  }
}

/// Game Card for the game selection grid
class GameCard extends StatefulWidget {
  final String gameId;
  final String name;
  final String description;
  final String therapyFocus;
  final VoidCallback? onTap;

  const GameCard({
    super.key,
    required this.gameId,
    required this.name,
    required this.description,
    required this.therapyFocus,
    this.onTap,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameColor = AuraTheme.getGameColor(widget.gameId);
    final gameIcon = AuraTheme.getGameIcon(widget.gameId);

    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onTap?.call();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(20),
          decoration: neumorphicDecoration(
            color: gameColor,
            radius: AuraTheme.radiusLarge,
            isPressed: _isPressed,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.7 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  gameIcon,
                  size: 32,
                  color: AuraTheme.textDark,
                ),
              ),
              const SizedBox(height: 16),
              
              // Game Name
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AuraTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              
              // Description
              Text(
                widget.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AuraTheme.textMedium,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Therapy Focus Tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.8 * 255).round()),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.therapyFocus,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AuraTheme.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Progress Bar with rounded design
class AuraProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;
  final String? label;

  const AuraProgressBar({
    super.key,
    required this.value,
    this.color,
    this.height = 12,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AuraTheme.textMedium,
                  ),
                ),
                Text(
                  '${(value * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AuraTheme.textDark,
                  ),
                ),
              ],
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: AuraTheme.surfaceLight,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color ?? AuraTheme.accentCornflower,
                    (color ?? AuraTheme.accentCornflower).withAlpha((0.7 * 255).round()),
                  ],
                ),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Child Avatar with initials
class ChildAvatar extends StatelessWidget {
  final String name;
  final double size;
  final Color? backgroundColor;

  const ChildAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.backgroundColor,
  });

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? AuraTheme.accentCornflower,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (backgroundColor ?? AuraTheme.accentCornflower).withAlpha((0.4 * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Score Badge
class ScoreBadge extends StatelessWidget {
  final int score;
  final String label;
  final Color? color;

  const ScoreBadge({
    super.key,
    required this.score,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? _getColorForScore(score);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha((0.15 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withAlpha((0.3 * 255).round())),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: badgeColor.withAlpha((0.8 * 255).round()),
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForScore(int score) {
    if (score >= 80) return AuraTheme.success;
    if (score >= 50) return AuraTheme.warning;
    return AuraTheme.textMedium;
  }
}
