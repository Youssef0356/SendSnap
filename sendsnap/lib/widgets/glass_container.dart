import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.70,
    this.borderRadius = 24,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.borderWidth = 1.2,
    this.boxShadow,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? Colors.white;
    final effectiveBorderColor = borderColor ?? Colors.white.withValues(alpha: 0.45);

    final innerDecoration = BoxDecoration(
      color: baseColor.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: effectiveBorderColor,
        width: borderWidth,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          baseColor.withValues(alpha: (opacity + 0.12).clamp(0.0, 1.0)),
          baseColor.withValues(alpha: (opacity * 0.75).clamp(0.0, 1.0)),
        ],
      ),
    );

    Widget innerContent = Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: innerDecoration,
      child: child,
    );

    Widget content;
    if (blur > 0) {
      content = RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: innerContent,
          ),
        ),
      );
    } else {
      content = innerContent;
    }

    if (boxShadow != null) {
      content = Container(
        margin: margin,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: boxShadow,
        ),
        child: content,
      );
    } else if (margin != null) {
      content = Padding(padding: margin!, child: content);
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }

    return content;
  }
}
