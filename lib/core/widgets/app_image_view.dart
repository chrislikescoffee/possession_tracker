import 'dart:convert';
import 'package:flutter/material.dart';

class AppImageView extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? fallbackWidget;

  const AppImageView({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackWidget,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.zero;

    if (imageUrl == null || imageUrl!.trim().isEmpty) {
      return ClipRRect(
        borderRadius: effectiveRadius,
        child: SizedBox(
          width: width,
          height: height,
          child: fallbackWidget ?? _buildDefaultFallback(context),
        ),
      );
    }

    final url = imageUrl!.trim();

    Widget imageWidget;

    if (url.startsWith('data:image/') || url.contains(';base64,')) {
      try {
        final commaIdx = url.indexOf(',');
        final base64Data = commaIdx != -1 ? url.substring(commaIdx + 1) : url;
        final bytes = base64Decode(base64Data);
        imageWidget = Image.memory(
          bytes,
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (ctx, __, ___) => fallbackWidget ?? _buildDefaultFallback(ctx),
        );
      } catch (_) {
        imageWidget = fallbackWidget ?? _buildDefaultFallback(context);
      }
    } else {
      imageWidget = Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          final theme = Theme.of(context);
          return Container(
            width: width,
            height: height,
            color: theme.cardTheme.color ?? theme.colorScheme.surface,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (ctx, __, ___) => fallbackWidget ?? _buildDefaultFallback(ctx),
      );
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: imageWidget,
    );
  }

  Widget _buildDefaultFallback([BuildContext? context]) {
    final theme = context != null ? Theme.of(context) : null;
    final bgColor = theme != null ? (theme.cardTheme.color ?? theme.colorScheme.surface) : const Color(0xFF1E293B);
    final iconColor = theme?.colorScheme.primary.withValues(alpha: 0.6) ?? const Color(0xFF64748B);

    return Container(
      width: width,
      height: height,
      color: bgColor,
      child: Center(
        child: Icon(Icons.image_outlined, size: 28, color: iconColor),
      ),
    );
  }
}
