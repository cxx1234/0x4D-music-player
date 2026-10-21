import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import '../../core/models/lyric_distance_blur_level.dart';
import '../../core/models/lyric_effect_strength.dart';
import '../../core/models/lyric_line_transition_style.dart';
import '../../core/models/lyric_slide_alignment.dart';
import '../../core/models/lyric_text_size.dart';
import '../../core/utils/lyric_document_parser.dart';
import '../../core/utils/lyric_preset.dart';

/// 内置示例：10 行（含翻译与一个间奏空白），循环 36 秒。
const String _kPreviewLyric = '''
[00:04.00]The streetlights stretch our shadows 街灯把影子拉得很长
[00:07.00]We walk the old road side by side 我们并肩走过旧路
[00:10.00]The wind scatters the words we never said 风把没说完的话吹散
[00:13.00]Only our heartbeats echo in the night 只剩心跳在夜里回响
[00:17.00]
[00:20.00]If time could stop right here 如果时间能停在这里
[00:23.00]I would stay a little longer 我会再多留一会儿
[00:26.00]Every corner holds a memory 每个角落都藏着回忆
[00:29.00]The city hums a quiet song 城市低声哼着歌
[00:32.00]We let the night carry us home 让夜色带我们回家
''';

const Duration _kPreviewLoop = Duration(seconds: 36);

/// 歌词显示设置页的实时预览：内置示例循环播放，设置变化立即反映。
///
/// 用独立 controller / 进度源，不碰真实播放器；离开页面（`TickerMode` 关闭）
/// 时自动停止采样。
class LyricsPreview extends StatefulWidget {
  const LyricsPreview({
    super.key,
    required this.textSize,
    required this.showTranslation,
    required this.wordHighlight,
    required this.wordLift,
    required this.effectStrength,
    required this.lineTransition,
    required this.slideAlignment,
    required this.lineWave,
    required this.distanceBlur,
    required this.countdown,
  });

  final LyricTextSize textSize;
  final bool showTranslation;
  final bool wordHighlight;
  final bool wordLift;
  final LyricEffectStrength effectStrength;
  final LyricLineTransitionStyle lineTransition;
  final LyricSlideAlignment slideAlignment;
  final bool lineWave;
  final LyricDistanceBlurLevel distanceBlur;
  final bool countdown;

  @override
  State<LyricsPreview> createState() => _LyricsPreviewState();
}

class _LyricsPreviewState extends State<LyricsPreview>
    with SingleTickerProviderStateMixin {
  late final _PreviewProgressSource _source;
  late final LyricController _controller;
  late final Ticker _ticker;

  LyricPreset? _preset;
  ({
    LyricTextSize size,
    bool wordHighlight,
    bool wordLift,
    LyricEffectStrength effectStrength,
    LyricLineTransitionStyle lineTransition,
    LyricSlideAlignment slideAlignment,
    bool lineWave,
    LyricDistanceBlurLevel distanceBlur,
    bool countdown,
  })?
  _presetKey;
  ThemeData? _presetTheme;

  @override
  void initState() {
    super.initState();
    _source = _PreviewProgressSource();
    _controller = LyricController(progressSource: _source);
    _loadDocument();
    // Ticker 会跟随 TickerMode：页面被覆盖/隐藏时回调停止。
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(covariant LyricsPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showTranslation != widget.showTranslation) {
      // loadDocument 保留当前播放位置，预览不会跳回开头。
      _loadDocument();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _loadDocument() {
    final parsed = parseLyricContent(
      _kPreviewLyric,
      includeTranslation: widget.showTranslation,
    );
    _controller.loadDocument(parsed.document);
  }

  void _onTick(Duration elapsed) {
    _source.position = Duration(
      microseconds: elapsed.inMicroseconds % _kPreviewLoop.inMicroseconds,
    );
  }

  LyricPreset _buildPreset(ThemeData theme) {
    final key = (
      size: widget.textSize,
      wordHighlight: widget.wordHighlight,
      wordLift: widget.wordLift,
      effectStrength: widget.effectStrength,
      lineTransition: widget.lineTransition,
      slideAlignment: widget.slideAlignment,
      lineWave: widget.lineWave,
      distanceBlur: widget.distanceBlur,
      countdown: widget.countdown,
    );
    if (_preset == null || _presetKey != key || _presetTheme != theme) {
      _preset = buildLyricPreset(
        theme: theme,
        size: key.size,
        wordHighlight: key.wordHighlight,
        wordLift: key.wordLift,
        effectStrength: key.effectStrength,
        lineTransition: key.lineTransition,
        slideAlignment: key.slideAlignment,
        lineWave: key.lineWave,
        distanceBlur: key.distanceBlur,
        countdown: key.countdown,
      );
      _presetKey = key;
      _presetTheme = theme;
    }
    return _preset!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '循环预览',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LyricView(
                controller: _controller,
                preset: _buildPreset(theme),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 预览专用进度源：位置由页面 Ticker 推动，恒为“播放中”。
class _PreviewProgressSource implements LyricProgressSource {
  Duration _position = Duration.zero;

  set position(Duration value) => _position = value;

  @override
  Duration get position => _position;

  @override
  bool get isAdvancing => true;

  @override
  Stream<void> get changes => const Stream<void>.empty();
}
