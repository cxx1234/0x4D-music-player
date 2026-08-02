import 'dart:io';

import 'package:flutter/material.dart';

/// Displays cached album art for a song.
///
/// Loads the image from [albumArtFilePath] (a local file written by
/// [AlbumArtCacheService]).  If [hasEmbeddedArt] is false or the file
/// cannot be loaded, a fallback icon is shown instead.
class CachedAlbumArt extends StatelessWidget {
  /// Path to the cached album art file, or `null` if none was cached.
  final String? albumArtFilePath;

  /// Whether the source audio file has embedded album art.
  final bool hasEmbeddedArt;

  /// The desired size (both width and height) of the album art.
  final double size;

  /// Optional border radius.  Defaults to 8.
  final double borderRadius;

  const CachedAlbumArt({
    super.key,
    required this.albumArtFilePath,
    required this.hasEmbeddedArt,
    this.size = 300,
    this.borderRadius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine whether we have a valid cached file to display.
    Widget child;
    if (hasEmbeddedArt && albumArtFilePath != null) {
      final file = File(albumArtFilePath!);
      child = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(theme, size),
          // Fade in when the image loads.
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: child,
            );
          },
        ),
      );
    } else {
      child = _buildPlaceholder(theme, size);
    }

    // Wrap in a sized box so the widget always occupies the same space
    // even when no image is available.
    return SizedBox(width: size, height: size, child: child);
  }
}

/// Fallback placeholder widget used when no album art is available.
Widget _buildPlaceholder(ThemeData theme, double size) {
  // size 可能为 double.infinity（网格卡片用 Expanded 填满），此时图标取固定值。
  final iconSize = size.isFinite ? size * 0.35 : 48.0;
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: theme.colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(
      Icons.music_note_rounded,
      size: iconSize,
      color: theme.colorScheme.onPrimaryContainer,
    ),
  );
}
