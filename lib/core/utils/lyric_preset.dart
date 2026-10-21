import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import '../models/lyric_distance_blur_level.dart';
import '../models/lyric_effect_strength.dart';
import '../models/lyric_line_transition_style.dart';
import '../models/lyric_slide_alignment.dart';
import '../models/lyric_text_size.dart';

/// 高亮（当前播放）行相对普通行的额外字号放大系数（在三档缩放基础上再乘）。
const double kLyricActiveTextScale = 1.2;

/// 按主题 + 字号档位派生 [LyricPreset]。
///
/// 基底用 4.x 的默认 [LyricPreset]（居中、14/18 字号、左右 20 padding），
/// 再按迁移前的实际观感覆盖字号基准、行距、上下淡出、滚动时长与高亮色。
/// 播放页与设置页预览共用这一份，避免两边观感走样。
LyricPreset buildLyricPreset({
  required ThemeData theme,
  required LyricTextSize size,
  bool wordHighlight = true,
  bool wordLift = false,
  LyricEffectStrength effectStrength = LyricEffectStrength.standard,
  LyricLineTransitionStyle lineTransition = LyricLineTransitionStyle.classic,
  LyricSlideAlignment slideAlignment = LyricSlideAlignment.left,
  bool lineWave = false,
  LyricDistanceBlurLevel distanceBlur = LyricDistanceBlurLevel.off,
  bool countdown = true,
}) {
  final scale = size.scale;
  final isSlide = lineTransition == LyricLineTransitionStyle.slide;
  final slideLeft = slideAlignment == LyricSlideAlignment.left;
  final onSurface = theme.colorScheme.onSurface;
  final primary = theme.colorScheme.primary;
  TextStyle scaled(TextStyle s) =>
      s.copyWith(fontSize: (s.fontSize ?? 14) * scale);
  const base = LyricPreset();
  return base.copyWith(
    // 只有「滑入」使用左/右对齐；其余预设保持居中。
    textAlign: isSlide
        ? (slideLeft ? TextAlign.left : TextAlign.right)
        : TextAlign.center,
    contentAlignment: isSlide
        ? (slideLeft ? LyricContentAlignment.start : LyricContentAlignment.end)
        : LyricContentAlignment.center,
    textStyle: scaled(
      base.textStyle,
    ).copyWith(color: onSurface.withValues(alpha: 0.7)),
    activeTextStyle: scaled(base.activeTextStyle).copyWith(
      // 3.x default1 的高亮字号基准是 16（4.x 默认 18）；再叠加档位缩放
      // 与 [kLyricActiveTextScale]，保持迁移前的放大手感。
      fontSize: 16 * scale * kLyricActiveTextScale,
      color: onSurface,
      fontWeight: FontWeight.w600,
    ),
    translationTextStyle: scaled(base.translationTextStyle).copyWith(
      color: onSurface.withValues(alpha: 0.7),
      // 翻译副行加粗（与高亮主歌词字重一致）。
      fontWeight: FontWeight.w600,
    ),
    // 当前播放行的翻译副行跟随高亮（3.x 只改颜色，字号/字重继承副行样式）。
    activeTranslationTextStyle: scaled(
      base.translationTextStyle,
    ).copyWith(color: onSurface, fontWeight: FontWeight.w600),
    selectedTextColor: onSurface,
    selectedTranslationTextColor: onSurface.withValues(alpha: 0.8),
    // 3.x default1：lineGap 26 / translationLineGap 10 / fadeRange 80px。
    lineSpacing: 26,
    translationSpacing: 10,
    // 左/右对齐时给比居中模式更宽的横向留白：非激活行本身会向左/右偏 24px，
    // 44 = 默认 20 + 24，保证偏出去之后仍有至少 20px 的呼吸空间。
    padding: isSlide
        ? const EdgeInsets.symmetric(horizontal: 44)
        : base.padding,
    edgeFade: const LyricEdgeFade.pixels(top: 80, bottom: 80),
    // 3.x scrollDuration 240ms。
    scrollAnimation: const LyricScrollAnimation.fixed(
      duration: Duration(milliseconds: 240),
    ),
    highlight: wordHighlight
        ? LyricHighlight.solid(primary.withValues(alpha: 0.5))
        : const LyricHighlight.none(),
    lineTransition: isSlide
        ? _slideTransition(slideAlignment)
        : _lineTransition(lineTransition),
    // Apple Music 的行间配方：35ms 行间延迟、600ms / 12px 波浪、64px 滞后上限。
    lineMotion: lineWave
        ? const LyricLineMotion(
            delay: Duration(milliseconds: 35),
            maxDelay: Duration(milliseconds: 140),
            waveDuration: Duration(milliseconds: 600),
            waveAmplitude: 12,
            maxLag: 64,
          )
        : const LyricLineMotion(),
    // 浏览（拖动/选中）时保持清晰，恢复跟随后再模糊；每行 +1 sigma。
    distanceBlur: LyricDistanceBlur(
      maxSigma: distanceBlur.maxSigma,
      sigmaPerLine: 1,
      whenBrowsing: false,
    ),
    countdown: countdown ? const LyricCountdown() : const LyricCountdown.none(),
    // 普通 LRC 没有词级时间：开填充或跳动时模拟，否则两者都不会逐字推进。
    wordEffects: LyricWordEffects(
      lift: wordLift ? effectStrength.lift : 0,
      liftDuration: LyricEffectStrength.liftDuration,
      simulateTiming: wordLift || wordHighlight,
    ),
  );
}

LyricLineTransition _lineTransition(LyricLineTransitionStyle style) {
  return switch (style) {
    LyricLineTransitionStyle.classic => LyricLineTransitions.classic,
    LyricLineTransitionStyle.scale => _softScaleTransition,
    // slide 走 _slideTransition（需要对齐方向），这里只作兜底。
    LyricLineTransitionStyle.slide => LyricLineTransitions.slideFade,
    LyricLineTransitionStyle.none => LyricLineTransitions.none,
  };
}

/// 滑入：从对齐的那一侧横向进入，并带一点下移 + 淡入。
LyricLineTransition _slideTransition(LyricSlideAlignment alignment) {
  final dx = alignment == LyricSlideAlignment.left ? -24.0 : 24.0;
  return LyricLineTransition.effects([
    LyricLineEffect.slide(Offset(dx, 8)),
    LyricLineEffect.fade(.5),
  ]);
}

/// 缩放：先放大一点，再平滑收束到正常大小；只有一次起伏，不做弹簧振荡。
LyricLineVisualState _softScale(LyricLineTransitionContext context) {
  final state = LyricLineVisualState.lerp(
    context.from,
    context.to,
    context.progress,
  );
  final bump = context.entering ? .08 : .02;
  return LyricLineVisualState(
    offset: state.offset,
    scale: state.scale * (1 + bump * math.sin(math.pi * context.progress)),
    opacity: state.opacity,
    blurSigma: state.blurSigma,
    activity: state.activity,
  );
}

final LyricLineTransition _softScaleTransition = LyricLineTransition.custom(
  _softScale,
  maxDisplacement: 0,
  maxBlurSigma: 0,
  maxScale: 1.06,
  effects: const [LyricLineEffect.scale(.92), LyricLineEffect.fade(.55)],
  enterDuration: const Duration(milliseconds: 500),
  exitDuration: const Duration(milliseconds: 300),
);
