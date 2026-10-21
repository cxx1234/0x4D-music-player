import 'package:flutter/material.dart';

import '../../core/models/lyric_distance_blur_level.dart';
import '../../core/models/lyric_effect_strength.dart';
import '../../core/models/lyric_line_transition_style.dart';
import '../../core/models/lyric_slide_alignment.dart';
import '../../core/models/lyric_text_size.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/detail_top_bar.dart';
import 'lyrics_preview.dart';

/// 歌词显示设置：字号、翻译副行（后续的样式 / 动效 / 倒计时也归在这里）。
class LyricsSettingsPage extends StatefulWidget {
  const LyricsSettingsPage({super.key});

  @override
  State<LyricsSettingsPage> createState() => _LyricsSettingsPageState();
}

class _LyricsSettingsPageState extends State<LyricsSettingsPage> {
  late LyricTextSize _textSize;
  late bool _showTranslation;
  late bool _wordHighlight;
  late bool _wordLift;
  late LyricEffectStrength _effectStrength;
  late LyricLineTransitionStyle _lineTransition;
  late LyricSlideAlignment _slideAlignment;
  late bool _lineWave;
  late LyricDistanceBlurLevel _distanceBlur;
  late bool _countdown;

  @override
  void initState() {
    super.initState();
    // 页面可独立构建（测试 / 启动早期），此时用默认值而非抛错。
    final ready = ServiceLocator.isReady;
    _textSize = ready
        ? ServiceLocator.settings.lyricTextSize
        : LyricTextSize.medium;
    _showTranslation = ready ? ServiceLocator.settings.showTranslation : true;
    _wordHighlight = ready ? ServiceLocator.settings.lyricWordHighlight : true;
    _wordLift = ready ? ServiceLocator.settings.lyricWordLift : false;
    _effectStrength = ready
        ? ServiceLocator.settings.lyricEffectStrength
        : LyricEffectStrength.standard;
    _lineTransition = ready
        ? ServiceLocator.settings.lyricLineTransition
        : LyricLineTransitionStyle.classic;
    _slideAlignment = ready
        ? ServiceLocator.settings.lyricSlideAlignment
        : LyricSlideAlignment.left;
    _lineWave = ready ? ServiceLocator.settings.lyricLineWave : false;
    _distanceBlur = ready
        ? ServiceLocator.settings.lyricDistanceBlur
        : LyricDistanceBlurLevel.off;
    _countdown = ready ? ServiceLocator.settings.lyricCountdown : true;
  }

  void _setTextSize(LyricTextSize size) {
    if (size == _textSize) return;
    setState(() => _textSize = size);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricTextSize(size);
    }
  }

  void _setShowTranslation(bool value) {
    if (value == _showTranslation) return;
    setState(() => _showTranslation = value);
    if (!ServiceLocator.isReady) return;
    ServiceLocator.settings.setShowTranslation(value);
    // 常驻歌词 VM 同步，播放页下次打开无需再重载歌词。
    ServiceLocator.lyrics.setShowTranslation(value);
  }

  void _setWordHighlight(bool value) {
    if (value == _wordHighlight) return;
    setState(() => _wordHighlight = value);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricWordHighlight(value);
    }
  }

  void _setWordLift(bool value) {
    if (value == _wordLift) return;
    setState(() => _wordLift = value);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricWordLift(value);
    }
  }

  void _setEffectStrength(LyricEffectStrength strength) {
    if (strength == _effectStrength) return;
    setState(() => _effectStrength = strength);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricEffectStrength(strength);
    }
  }

  void _setLineTransition(LyricLineTransitionStyle style) {
    if (style == _lineTransition) return;
    setState(() => _lineTransition = style);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricLineTransition(style);
    }
  }

  void _setSlideAlignment(LyricSlideAlignment alignment) {
    if (alignment == _slideAlignment) return;
    setState(() => _slideAlignment = alignment);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricSlideAlignment(alignment);
    }
  }

  void _setLineWave(bool value) {
    if (value == _lineWave) return;
    setState(() => _lineWave = value);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricLineWave(value);
    }
  }

  void _setDistanceBlur(LyricDistanceBlurLevel level) {
    if (level == _distanceBlur) return;
    setState(() => _distanceBlur = level);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricDistanceBlur(level);
    }
  }

  void _setCountdown(bool value) {
    if (value == _countdown) return;
    setState(() => _countdown = value);
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.setLyricCountdown(value);
    }
  }

  /// 选项副标题样式：比 bodySmall 再小一档、偏灰（与设置页/SongTile 一致）。
  TextStyle _subtitleStyle(ThemeData theme) => theme.textTheme.bodySmall!
      .copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant);

  /// 选项行的标题+副标题组合块（两行整体垂直居中，与设置页一致）。
  Widget _buildOptionText(ThemeData theme, String title, String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _subtitleStyle(theme),
        ),
      ],
    );
  }

  /// 44×26 紧凑开关：M3 Switch 默认 52×32，非等比缩放（视觉+命中区同步）。
  Widget _buildCompactSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    const targetW = 44.0, targetH = 26.0;
    const defaultW = 52.0, defaultH = 32.0;
    return SizedBox(
      width: targetW,
      height: targetH,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          targetW / defaultW,
          targetH / defaultH,
          1,
        ),
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextCard(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 本行不是 ListTile，裸 Icon 需显式跟随主题着色。
                  Icon(
                    Icons.format_size_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('字号', style: theme.textTheme.titleMedium),
                        Text(
                          '调整歌词与翻译的文字大小',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _subtitleStyle(theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<LyricTextSize>(
                    showSelectedIcon: false,
                    segments: [
                      for (final size in LyricTextSize.values)
                        ButtonSegment(value: size, label: Text(size.label)),
                    ],
                    selected: {_textSize},
                    onSelectionChanged: (selection) =>
                        _setTextSize(selection.first),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.translate_rounded),
            title: _buildOptionText(theme, '翻译副行', '有翻译时在原文下方显示'),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _showTranslation,
              onChanged: _setShowTranslation,
            ),
            onTap: () => _setShowTranslation(!_showTranslation),
          ),
        ],
      ),
    );
  }

  Widget _buildHint(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 6, 40, 0),
      child: Text(text, style: _subtitleStyle(theme)),
    );
  }

  Widget _buildEffectsCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              ListTile(
                minVerticalPadding: 16,
                leading: const Icon(Icons.format_color_fill_rounded),
                title: _buildOptionText(theme, '逐字填充', '唱到的字逐渐填充主题色'),
                subtitle: null,
                trailing: _buildCompactSwitch(
                  value: _wordHighlight,
                  onChanged: _setWordHighlight,
                ),
                onTap: () => _setWordHighlight(!_wordHighlight),
              ),
              ListTile(
                minVerticalPadding: 16,
                leading: const Icon(Icons.arrow_upward_rounded),
                title: _buildOptionText(theme, '逐字跳动', '唱到的字向上跳一下（本句内保持）'),
                subtitle: null,
                trailing: _buildCompactSwitch(
                  value: _wordLift,
                  onChanged: _setWordLift,
                ),
                onTap: () => _setWordLift(!_wordLift),
              ),
              if (_wordLift)
                SizedBox(
                  height: 72,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // 本行不是 ListTile，裸 Icon 需显式跟随主题着色。
                        Icon(
                          Icons.tune_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('效果强度', style: theme.textTheme.titleMedium),
                              Text(
                                '逐字跳起的高度',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _subtitleStyle(theme),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SegmentedButton<LyricEffectStrength>(
                          showSelectedIcon: false,
                          segments: [
                            for (final strength in LyricEffectStrength.values)
                              ButtonSegment(
                                value: strength,
                                label: Text(strength.label),
                              ),
                          ],
                          selected: {_effectStrength},
                          onSelectionChanged: (selection) =>
                              _setEffectStrength(selection.first),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildHint(theme, '普通 LRC 会自动模拟逐字时间；QRC / YRC 使用歌词自带的词级时间。'),
      ],
    );
  }

  Widget _buildTransitionCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PopupMenuButton<LyricLineTransitionStyle>(
            initialValue: _lineTransition,
            tooltip: '切句动画',
            onSelected: _setLineTransition,
            itemBuilder: (context) => [
              for (final style in LyricLineTransitionStyle.values)
                CheckedPopupMenuItem(
                  value: style,
                  checked: style == _lineTransition,
                  child: Text(style.label),
                ),
            ],
            child: ListTile(
              minVerticalPadding: 16,
              leading: const Icon(Icons.animation_rounded),
              title: _buildOptionText(
                theme,
                '切句动画',
                _lineTransition.description,
              ),
              subtitle: null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _lineTransition.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, color: muted),
                ],
              ),
            ),
          ),
          // 「滑入」才需要选对齐边；其余预设保持居中。
          if (_lineTransition == LyricLineTransitionStyle.slide)
            SizedBox(
              height: 72,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(
                      _slideAlignment == LyricSlideAlignment.left
                          ? Icons.format_align_left_rounded
                          : Icons.format_align_right_rounded,
                      color: muted,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('对齐', style: theme.textTheme.titleMedium),
                          Text(
                            '滑动方向跟随对齐边',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _subtitleStyle(theme),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<LyricSlideAlignment>(
                      showSelectedIcon: false,
                      segments: [
                        for (final alignment in LyricSlideAlignment.values)
                          ButtonSegment(
                            value: alignment,
                            label: Text(alignment.label),
                          ),
                      ],
                      selected: {_slideAlignment},
                      onSelectionChanged: (selection) =>
                          _setSlideAlignment(selection.first),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLineMotionCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.waves_rounded),
            title: _buildOptionText(theme, '行间波浪', '整行依次错位并轻微起伏'),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _lineWave,
              onChanged: _setLineWave,
            ),
            onTap: () => _setLineWave(!_lineWave),
          ),
        ),
        _buildHint(theme, '作用在整行上，和逐字跳动可以叠加；同时开启可能偏花。'),
      ],
    );
  }

  Widget _buildBlurCard(ThemeData theme) {
    final muted = theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            height: 72,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.blur_on_rounded, color: muted),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('距离模糊', style: theme.textTheme.titleMedium),
                        Text(
                          '离当前句越远越模糊；浏览时保持清晰',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _subtitleStyle(theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SegmentedButton<LyricDistanceBlurLevel>(
                    showSelectedIcon: false,
                    segments: [
                      for (final level in LyricDistanceBlurLevel.values)
                        ButtonSegment(value: level, label: Text(level.label)),
                    ],
                    selected: {_distanceBlur},
                    onSelectionChanged: (selection) =>
                        _setDistanceBlur(selection.first),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildHint(theme, '每行会多一个离屏模糊层；低配设备或叠加大量动效时建议关闭。'),
      ],
    );
  }

  Widget _buildCountdownCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          elevation: 0,
          color: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.more_horiz_rounded),
            title: _buildOptionText(theme, '倒计时圆点', '前奏/间奏显示三个渐隐圆点'),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _countdown,
              onChanged: _setCountdown,
            ),
            onTap: () => _setCountdown(!_countdown),
          ),
        ),
        _buildHint(theme, '普通 LRC 需要在间奏处留空白时间戳（如 [00:12.00]）才会显示。'),
      ],
    );
  }

  /// 宽屏左侧才放预览；窄屏只保留设置项。
  static const double _kPreviewBreakpoint = 780;

  Widget _buildSettingsList(ThemeData theme) {
    // 项目约定：含 ListTile/InkWell 的滚动区外包透明 Material + Clip.hardEdge。
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _buildSectionHeader(theme, '文字'),
          _buildTextCard(theme),
          _buildSectionHeader(theme, '文本效果'),
          _buildEffectsCard(theme),
          _buildSectionHeader(theme, '切句动画'),
          _buildTransitionCard(theme),
          _buildSectionHeader(theme, '行间动效'),
          _buildLineMotionCard(theme),
          _buildSectionHeader(theme, '距离模糊'),
          _buildBlurCard(theme),
          _buildSectionHeader(theme, '倒计时'),
          _buildCountdownCard(theme),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const DetailTopBar(title: '歌词显示'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _kPreviewBreakpoint) {
            return _buildSettingsList(theme);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 12, 24),
                  child: LyricsPreview(
                    textSize: _textSize,
                    showTranslation: _showTranslation,
                    wordHighlight: _wordHighlight,
                    wordLift: _wordLift,
                    effectStrength: _effectStrength,
                    lineTransition: _lineTransition,
                    slideAlignment: _slideAlignment,
                    lineWave: _lineWave,
                    distanceBlur: _distanceBlur,
                    countdown: _countdown,
                  ),
                ),
              ),
              Expanded(flex: 4, child: _buildSettingsList(theme)),
            ],
          );
        },
      ),
    );
  }
}
