import 'package:flutter/material.dart';

import '../../core/models/lyric_distance_blur_level.dart';
import '../../core/models/lyric_effect_strength.dart';
import '../../core/models/lyric_line_transition_style.dart';
import '../../core/models/lyric_slide_alignment.dart';
import '../../core/models/lyric_text_size.dart';
import '../../core/services/service_locator.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/l10n.dart';
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
                        Text(
                          context.l10n.lyricsTextSizeTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          context.l10n.lyricsTextSizeSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _subtitleStyle(theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _shrinkableSegmented(
                    SegmentedButton<LyricTextSize>(
                      showSelectedIcon: false,
                      segments: [
                        for (final size in LyricTextSize.values)
                          ButtonSegment(
                            value: size,
                            label: Text(size.label(context.l10n)),
                          ),
                      ],
                      selected: {_textSize},
                      onSelectionChanged: (selection) =>
                          _setTextSize(selection.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            minVerticalPadding: 16,
            leading: const Icon(Icons.translate_rounded),
            title: _buildOptionText(
              theme,
              context.l10n.lyricsTranslationTitle,
              context.l10n.lyricsTranslationSubtitle,
            ),
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

  /// 可收缩的分段按钮：英文标签比中文长，窄行里允许等比缩小而不是溢出。
  Widget _shrinkableSegmented<T>(SegmentedButton<T> child) {
    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: child,
        ),
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
                title: _buildOptionText(
                  theme,
                  context.l10n.lyricsWordFillTitle,
                  context.l10n.lyricsWordFillSubtitle,
                ),
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
                title: _buildOptionText(
                  theme,
                  context.l10n.lyricsWordLiftTitle,
                  context.l10n.lyricsWordLiftSubtitle,
                ),
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
                              Text(
                                context.l10n.lyricsEffectStrengthTitle,
                                style: theme.textTheme.titleMedium,
                              ),
                              Text(
                                context.l10n.lyricsEffectStrengthSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _subtitleStyle(theme),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _shrinkableSegmented(
                          SegmentedButton<LyricEffectStrength>(
                            showSelectedIcon: false,
                            segments: [
                              for (final strength in LyricEffectStrength.values)
                                ButtonSegment(
                                  value: strength,
                                  label: Text(strength.label(context.l10n)),
                                ),
                            ],
                            selected: {_effectStrength},
                            onSelectionChanged: (selection) =>
                                _setEffectStrength(selection.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildHint(theme, context.l10n.lyricsWordTimingHint),
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
            tooltip: context.l10n.lyricsTransitionTitle,
            onSelected: _setLineTransition,
            itemBuilder: (context) => [
              for (final style in LyricLineTransitionStyle.values)
                CheckedPopupMenuItem(
                  value: style,
                  checked: style == _lineTransition,
                  child: Text(style.label(context.l10n)),
                ),
            ],
            child: ListTile(
              minVerticalPadding: 16,
              leading: const Icon(Icons.animation_rounded),
              title: _buildOptionText(
                theme,
                context.l10n.lyricsTransitionTitle,
                _lineTransition.description(context.l10n),
              ),
              subtitle: null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _lineTransition.label(context.l10n),
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
                          Text(
                            context.l10n.lyricsAlignmentTitle,
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            context.l10n.lyricsAlignmentSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _subtitleStyle(theme),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _shrinkableSegmented(
                      SegmentedButton<LyricSlideAlignment>(
                        showSelectedIcon: false,
                        segments: [
                          for (final alignment in LyricSlideAlignment.values)
                            ButtonSegment(
                              value: alignment,
                              label: Text(alignment.label(context.l10n)),
                            ),
                        ],
                        selected: {_slideAlignment},
                        onSelectionChanged: (selection) =>
                            _setSlideAlignment(selection.first),
                      ),
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
            title: _buildOptionText(
              theme,
              context.l10n.lyricsLineWaveTitle,
              context.l10n.lyricsLineWaveSubtitle,
            ),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _lineWave,
              onChanged: _setLineWave,
            ),
            onTap: () => _setLineWave(!_lineWave),
          ),
        ),
        _buildHint(theme, context.l10n.lyricsLineWaveHint),
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
                        Text(
                          context.l10n.lyricsBlurTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          context.l10n.lyricsBlurSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _subtitleStyle(theme),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _shrinkableSegmented(
                    SegmentedButton<LyricDistanceBlurLevel>(
                      showSelectedIcon: false,
                      segments: [
                        for (final level in LyricDistanceBlurLevel.values)
                          ButtonSegment(
                            value: level,
                            label: Text(level.label(context.l10n)),
                          ),
                      ],
                      selected: {_distanceBlur},
                      onSelectionChanged: (selection) =>
                          _setDistanceBlur(selection.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildHint(theme, context.l10n.lyricsBlurHint),
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
            title: _buildOptionText(
              theme,
              context.l10n.lyricsCountdownTitle,
              context.l10n.lyricsCountdownSubtitle,
            ),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _countdown,
              onChanged: _setCountdown,
            ),
            onTap: () => _setCountdown(!_countdown),
          ),
        ),
        _buildHint(theme, context.l10n.lyricsCountdownHint),
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
          _buildSectionHeader(theme, context.l10n.lyricsSectionText),
          _buildTextCard(theme),
          _buildSectionHeader(theme, context.l10n.lyricsSectionEffects),
          _buildEffectsCard(theme),
          _buildSectionHeader(theme, context.l10n.lyricsTransitionTitle),
          _buildTransitionCard(theme),
          _buildSectionHeader(theme, context.l10n.lyricsSectionLineMotion),
          _buildLineMotionCard(theme),
          _buildSectionHeader(theme, context.l10n.lyricsBlurTitle),
          _buildBlurCard(theme),
          _buildSectionHeader(theme, context.l10n.lyricsSectionCountdown),
          _buildCountdownCard(theme),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: DetailTopBar(title: context.l10n.lyricsSettingsTitle),
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
