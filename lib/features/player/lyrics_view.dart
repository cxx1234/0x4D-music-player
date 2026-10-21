import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import '../../core/constants/motion.dart';
import '../../core/models/lyric_distance_blur_level.dart';
import '../../core/models/lyric_effect_strength.dart';
import '../../core/models/lyric_line_transition_style.dart';
import '../../core/models/lyric_slide_alignment.dart';
import '../../core/models/lyric_text_size.dart';
import '../../core/utils/lyric_preset.dart';
import 'player_ui_state.dart';

/// 歌词视图：上方菜单栏（文本大小）+ 歌词内容区。
///
/// 菜单栏样式与播放队列工具栏一致：surface 背景 + 左侧 bodySmall 文本 +
/// 右侧 20px IconButton。内容区在有歌词时渲染 flutter_lyric 的 [LyricView]，
/// 无歌词时显示"暂无歌词"占位。
class LyricsView extends StatefulWidget {
  final LyricController controller;
  final ThemeData theme;

  /// 跨会话播放器界面状态（读写歌词字号档位）。
  final PlayerUiState uiState;

  /// 窄版内嵌时传 true（宽版右栏为 false）：窄版菜单栏左侧留白 12，
  /// 与播放队列工具栏一致；宽版整体右侧留白 10。
  final bool isNarrow;

  /// 翻译显示开关变化回调（页面级，触发歌词重载）。
  final VoidCallback? onToggleTranslation;

  /// 歌词字号档位变化回调（页面级，负责写盘持久化）。
  final ValueChanged<LyricTextSize>? onTextSizeChanged;

  /// 当前歌词是否含翻译副行（内容事实，来自 [LyricsViewModel]）。
  /// 为 null 时不限制（按钮始终可点）；非 null 且为 false 时翻译按钮禁用。
  final ValueListenable<bool>? hasTranslation;

  /// 点击某句歌词的回调（4.x 把 tap 从 controller 移到了 View 上，
  /// `seekPosition` 已按 timeOffset 修正）。
  final ValueChanged<LyricLineDetails>? onLineTap;

  /// 打开「歌词显示设置」页；为 null 时不显示该按钮。
  final VoidCallback? onOpenSettings;

  const LyricsView({
    super.key,
    required this.controller,
    required this.theme,
    required this.uiState,
    this.isNarrow = false,
    this.hasTranslation,
    this.onToggleTranslation,
    this.onTextSizeChanged,
    this.onLineTap,
    this.onOpenSettings,
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  // 缓存 LyricPreset：仅字号档位/文本效果/主题变化时重建（避免播放页高频
  // rebuild 反复 relayout/repaint）。
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

  /// 「当前是否有歌词」：只在有/无切换时通知，避免 setPosition 每帧重建歌词树。
  final ValueNotifier<bool> _hasLyrics = ValueNotifier(false);

  ThemeData get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncHasLyrics);
    _syncHasLyrics();
  }

  @override
  void didUpdateWidget(covariant LyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncHasLyrics);
      widget.controller.addListener(_syncHasLyrics);
      _syncHasLyrics();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncHasLyrics);
    _hasLyrics.dispose();
    super.dispose();
  }

  void _syncHasLyrics() {
    final has = widget.controller.document?.lines.isNotEmpty ?? false;
    if (_hasLyrics.value != has) _hasLyrics.value = has;
  }

  LyricPreset _buildPreset() {
    final ui = widget.uiState;
    final key = (
      size: ui.lyricTextSize,
      wordHighlight: ui.lyricWordHighlight,
      wordLift: ui.lyricWordLift,
      effectStrength: ui.lyricEffectStrength,
      lineTransition: ui.lyricLineTransition,
      slideAlignment: ui.lyricSlideAlignment,
      lineWave: ui.lyricLineWave,
      distanceBlur: ui.lyricDistanceBlur,
      countdown: ui.lyricCountdown,
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

  Future<void> _showTextSizeMenu(BuildContext anchor) async {
    final box = anchor.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(anchor).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;
    final selected = await showMenu<LyricTextSize>(
      context: context,
      popUpAnimationStyle: kPopupMenuAnimationStyle,
      position: RelativeRect.fromRect(
        box.localToGlobal(Offset.zero) & box.size,
        Offset.zero & overlay.size,
      ),
      items: [
        for (final size in LyricTextSize.values)
          CheckedPopupMenuItem(
            value: size,
            checked: size == widget.uiState.lyricTextSize,
            child: Text(size.label),
          ),
      ],
    );
    if (selected != null && selected != widget.uiState.lyricTextSize) {
      setState(() => widget.uiState.lyricTextSize = selected);
      // 写盘持久化（设置页不展示该选项，但跨重启保留）。
      widget.onTextSizeChanged?.call(selected);
    }
  }

  /// 菜单栏：样式与 QueueView 工具栏一致（surface 背景 + 左文本 + 右按钮）。
  Widget _buildToolbar() {
    return Material(
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            // 窄版内嵌时左侧留白，与队列工具栏一致（宽版无额外 margin）。
            Padding(
              padding: EdgeInsets.only(left: widget.isNarrow ? 12 : 0),
              child: Text(
                '歌词',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            // 翻译显示开关（开启时主题色，关闭时淡色；歌词无翻译时禁用）。
            _buildTranslationButton(theme),
            // 用 Builder 取按钮自身 RenderBox，菜单从按钮附近弹出。
            Builder(
              builder: (anchor) => IconButton(
                icon: const Icon(Icons.text_fields_rounded, size: 20),
                tooltip: '文本大小',
                onPressed: () => _showTextSizeMenu(anchor),
              ),
            ),
            if (widget.onOpenSettings != null)
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                tooltip: '歌词显示设置',
                onPressed: widget.onOpenSettings,
              ),
          ],
        ),
      ),
    );
  }

  /// 翻译显示开关：歌词无翻译副行时禁用（避免"点了没反应"）。
  Widget _buildTranslationButton(ThemeData theme) {
    final listenable = widget.hasTranslation;
    if (listenable == null) {
      // 未提供有无翻译信息（如测试环境）：保持原行为，始终可点。
      return _translationButton(theme, enabled: true);
    }
    return ValueListenableBuilder<bool>(
      valueListenable: listenable,
      builder: (context, hasTranslation, _) =>
          _translationButton(theme, enabled: hasTranslation),
    );
  }

  Widget _translationButton(ThemeData theme, {required bool enabled}) {
    final active = widget.uiState.showTranslation;
    final color = !enabled
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
        : active
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return IconButton(
      icon: Icon(Icons.translate_rounded, size: 20, color: color),
      tooltip: active ? '关闭翻译' : '显示翻译',
      onPressed: enabled
          ? () {
              setState(() {
                widget.uiState.showTranslation =
                    !widget.uiState.showTranslation;
              });
              widget.onToggleTranslation?.call();
            }
          : null,
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lyrics_rounded,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            '暂无歌词',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 歌词区自成一合成层：当前行高亮/滚动刷新不波及相邻面板。
    return RepaintBoundary(
      child: Column(
        children: [
          _buildToolbar(),
          Expanded(
            // 宽模式仅内容区右侧留白 10（顶栏保持与队列一致，窄模式不额外加）。
            child: Padding(
              padding: EdgeInsets.only(right: widget.isNarrow ? 0 : 20),
              child: ValueListenableBuilder<bool>(
                valueListenable: _hasLyrics,
                builder: (context, hasLyrics, _) {
                  if (!hasLyrics) return _buildEmpty();
                  return LyricView(
                    controller: widget.controller,
                    preset: _buildPreset(),
                    onLineTap: widget.onLineTap,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
