/// 「滑入」切句动画的对齐方向。
enum LyricSlideAlignment {
  left,
  right;

  /// 从持久化的枚举名恢复；未知值回退到左对齐。
  static LyricSlideAlignment fromName(String? name) {
    if (name == null) return LyricSlideAlignment.left;
    return LyricSlideAlignment.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricSlideAlignment.left,
    );
  }
}
