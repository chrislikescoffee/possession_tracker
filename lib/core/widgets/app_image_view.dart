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
          child: fallbackWidget ?? _buildDefaultFallback(),
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
          errorBuilder: (_, __, ___) => fallbackWidget ?? _buildDefaultFallback(),
        );
      } catch (_) {
        imageWidget = fallbackWidget ?? _buildDefaultFallback();
      }
    } else {
      imageWidget = Image.network(
        url,
        fit: fit,
        width: width,
        height: height,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width,
            height: height,
            color: const Color(0xFF131B2E),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => fallbackWidget ?? _buildDefaultFallback(),
      );
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: imageWidget,
    );
  }

  Widget _buildDefaultFallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFF1E293B),
      child: const Center(
        child: Icon(Icons.image_outlined, size: 28, color: Color(0xFF64748B)),
      ),
    );
  }
}
