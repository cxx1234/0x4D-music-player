import '../core/models/accent_color.dart';
import '../core/models/lyric_distance_blur_level.dart';
import '../core/models/lyric_effect_strength.dart';
import '../core/models/lyric_line_transition_style.dart';
import '../core/models/lyric_slide_alignment.dart';
import '../core/models/lyric_text_size.dart';
import 'app_localizations.dart';

/// core 枚举的展示文案映射。
///
/// core 层不持有 UI 文案；界面按当前 locale 调这些扩展取文案。
extension AccentColorL10n on AccentColor {
  String label(AppLocalizations l10n) => switch (this) {
    AccentColor.system => l10n.commonFollowSystem,
    AccentColor.graphite => l10n.accentGraphite,
    AccentColor.deepPurple => l10n.accentDeepPurple,
    AccentColor.indigo => l10n.accentIndigo,
    AccentColor.blue => l10n.accentBlue,
    AccentColor.cyan => l10n.accentCyan,
    AccentColor.green => l10n.accentGreen,
    AccentColor.orange => l10n.accentOrange,
    AccentColor.red => l10n.accentRed,
    AccentColor.pink => l10n.accentPink,
    AccentColor.blueGrey => l10n.accentBlueGrey,
  };
}

extension LyricTextSizeL10n on LyricTextSize {
  String label(AppLocalizations l10n) => switch (this) {
    LyricTextSize.small => l10n.lyricTextSizeSmall,
    LyricTextSize.medium => l10n.lyricTextSizeMedium,
    LyricTextSize.large => l10n.lyricTextSizeLarge,
  };
}

extension LyricEffectStrengthL10n on LyricEffectStrength {
  String label(AppLocalizations l10n) => switch (this) {
    LyricEffectStrength.standard => l10n.lyricEffectStandard,
    LyricEffectStrength.strong => l10n.lyricEffectStrong,
  };
}

extension LyricLineTransitionStyleL10n on LyricLineTransitionStyle {
  String label(AppLocalizations l10n) => switch (this) {
    LyricLineTransitionStyle.classic => l10n.lyricTransitionClassic,
    LyricLineTransitionStyle.scale => l10n.lyricTransitionScale,
    LyricLineTransitionStyle.slide => l10n.lyricTransitionSlide,
    LyricLineTransitionStyle.none => l10n.lyricTransitionNone,
  };

  String description(AppLocalizations l10n) => switch (this) {
    LyricLineTransitionStyle.classic => l10n.lyricTransitionClassicDescription,
    LyricLineTransitionStyle.scale => l10n.lyricTransitionScaleDescription,
    LyricLineTransitionStyle.slide => l10n.lyricTransitionSlideDescription,
    LyricLineTransitionStyle.none => l10n.lyricTransitionNoneDescription,
  };
}

extension LyricSlideAlignmentL10n on LyricSlideAlignment {
  String label(AppLocalizations l10n) => switch (this) {
    LyricSlideAlignment.left => l10n.lyricAlignmentLeft,
    LyricSlideAlignment.right => l10n.lyricAlignmentRight,
  };
}

extension LyricDistanceBlurLevelL10n on LyricDistanceBlurLevel {
  String label(AppLocalizations l10n) => switch (this) {
    LyricDistanceBlurLevel.off => l10n.lyricBlurOff,
    LyricDistanceBlurLevel.light => l10n.lyricBlurLight,
    LyricDistanceBlurLevel.standard => l10n.lyricBlurStandard,
  };
}
