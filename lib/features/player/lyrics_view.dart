import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import '../../core/constants/motion.dart';
import '../../core/models/lyric_text_size.dart';
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
  });

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  /// 高亮（当前播放）行相对普通行的额外字号放大系数（在三档缩放基础上再乘）。
  static const double _kActiveTextScale = 1.2;

  // 缓存 LyricPreset：仅字号档位/主题变化时重建（避免播放页高频 rebuild 反复
  // relayout/repaint）。
  LyricPreset? _preset;
  LyricTextSize? _presetSize;
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
    final size = widget.uiState.lyricTextSize;
    if (_preset == null || _presetSize != size || _presetTheme != theme) {
      _preset = _computePreset(size);
      _presetSize = size;
      _presetTheme = theme;
    }
    return _preset!;
  }

  /// 按主题 + 字号档位派生 LyricPreset。
  ///
  /// 基底用 4.x 的默认 [LyricPreset]（居中、14/18 字号、左右 20 padding，
  /// 与 3.x `LyricStyles.default1` 基本一致），再按迁移前的实际观感覆盖
  /// 字号基准、行距、上下淡出、滚动时长与高亮色。
  LyricPreset _computePreset(LyricTextSize size) {
    final scale = size.scale;
    final onSurface = theme.colorScheme.onSurface;
    final primary = theme.colorScheme.primary;
    TextStyle scaled(TextStyle s) =>
        s.copyWith(fontSize: (s.fontSize ?? 14) * scale);
    const base = LyricPreset();
    return base.copyWith(
      textStyle: scaled(
        base.textStyle,
      ).copyWith(color: onSurface.withValues(alpha: 0.7)),
      activeTextStyle: scaled(base.activeTextStyle).copyWith(
        // 3.x default1 的高亮字号基准是 16（4.x 默认 18）；再叠加档位缩放
        // 与 _kActiveTextScale，保持迁移前的放大手感。
        fontSize: 16 * scale * _kActiveTextScale,
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      translationTextStyle: scaled(base.translationTextStyle).copyWith(
        color: onSurface.withValues(alpha: 0.7),
        // 翻译副行加粗（与高亮主歌词字重一致）。
        fontWeight: FontWeight.w600,
      ),
      // 当前播放行的翻译副行跟随高亮（3.x 只改颜色，字号/字重继承副行样式）。
      activeTranslationTextStyle: scaled(base.translationTextStyle).copyWith(
        color: onSurface,
        fontWeight: FontWeight.w600,
      ),
      selectedTextColor: onSurface,
      selectedTranslationTextColor: onSurface.withValues(alpha: 0.8),
      // 3.x default1：lineGap 26 / translationLineGap 10 / fadeRange 80px。
      lineSpacing: 26,
      translationSpacing: 10,
      edgeFade: const LyricEdgeFade.pixels(top: 80, bottom: 80),
      // 3.x scrollDuration 240ms。
      scrollAnimation: const LyricScrollAnimation.fixed(
        duration: Duration(milliseconds: 240),
      ),
      highlight: LyricHighlight.solid(primary.withValues(alpha: 0.5)),
    );
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
