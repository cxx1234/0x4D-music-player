import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

/// 解码尺寸防抖时长：窗口 resize 期间沿用上一次解码尺寸，停止后重解码一次。
const Duration _kDecodeDebounce = Duration(milliseconds: 250);

/// Displays cached album art for a song.
///
/// Loads the image from [albumArtFilePath] (a local file written by
/// [AlbumArtCacheService]).  If [hasEmbeddedArt] is false or the file
/// cannot be loaded, a fallback icon is shown instead.
class CachedAlbumArt extends StatefulWidget {
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
  State<CachedAlbumArt> createState() => _CachedAlbumArtState();
}

class _CachedAlbumArtState extends State<CachedAlbumArt> {
  /// 防抖计时器：尺寸连续变化时不断重置，停止 [_kDecodeDebounce] 后才重解码。
  Timer? _debounce;

  /// 用于解码的尺寸（防抖后的稳定值）；显示尺寸始终用 [CachedAlbumArt.size]。
  late double _decodeSize;

  @override
  void initState() {
    super.initState();
    _decodeSize = widget.size;
  }

  @override
  void didUpdateWidget(covariant CachedAlbumArt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.size == widget.size) return;
    _debounce?.cancel();
    _debounce = Timer(_kDecodeDebounce, () {
      if (!mounted || _decodeSize == widget.size) return;
      setState(() => _decodeSize = widget.size);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.size;

    // 降采样解码：缓存封面是原始分辨率（常 1000~3000px），按显示尺寸×
    // 设备像素比解码即可——避免全尺寸位图占内存，以及 ImageCache 逐出后
    // 滚动回来反复全尺寸重解码（44px 行封面也解整张图）。
    // 解码尺寸走防抖后的 [_decodeSize]：窗口 resize 期间沿用上一次解码
    // 位图（拉伸/压缩显示），停止 250ms 后才按最终尺寸重解码一次。
    final decodeWidth = albumArtDecodeWidth(
      _decodeSize,
      MediaQuery.devicePixelRatioOf(context),
    );

    // Determine whether we have a valid cached file to display.
    Widget child;
    if (widget.hasEmbeddedArt && widget.albumArtFilePath != null) {
      final file = File(widget.albumArtFilePath!);
      child = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Image.file(
          file,
          width: size,
          height: size,
          fit: BoxFit.cover,
          cacheWidth: decodeWidth,
          // 重载期间保留上一帧，避免透明帧闪烁（配合降采样减少重解码）。
          gaplessPlayback: true,
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

/// 封面解码宽度钳制范围（物理像素）。
const int _kMinDecodeSize = 32;
const int _kMaxDecodeSize = 2048;

/// [size] 为 double.infinity（网格卡片 Expanded 填满 / 播放列表 2×2 拼图）时的
/// 解码尺寸（逻辑像素）。网格卡片最大宽 ~200（maxCrossAxisExtent），
/// 256 已足够覆盖且远小于原图。
const double _kDefaultDecodeSize = 256;

/// 计算封面解码宽度（物理像素）：按显示尺寸×设备像素比降采样并钳制；
/// [size] 为无限时用 [_kDefaultDecodeSize]（此时无法从布局得知真实尺寸）。
@visibleForTesting
int albumArtDecodeWidth(double size, double dpr) {
  final target = size.isFinite ? size * dpr : _kDefaultDecodeSize * dpr;
  return target.round().clamp(_kMinDecodeSize, _kMaxDecodeSize).toInt();
}
