/// 歌词切句动画风格。
///
/// 只暴露少数几个稳定的内置轨迹；更多参数留在库内部，避免设置页变成调参器。
enum LyricLineTransitionStyle {
  classic,
  scale,
  slide,
  none;

  /// 从持久化的枚举名恢复；未知值回退到经典。
  static LyricLineTransitionStyle fromName(String? name) {
    if (name == null) return LyricLineTransitionStyle.classic;
    return LyricLineTransitionStyle.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricLineTransitionStyle.classic,
    );
  }
}
