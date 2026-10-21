/// 歌词距离模糊档位（离当前句越远，模糊越强）。
enum LyricDistanceBlurLevel {
  off('关', 0),
  light('轻', 2),
  standard('标准', 4);

  const LyricDistanceBlurLevel(this.label, this.maxSigma);

  final String label;

  /// 最大模糊强度（逻辑像素 sigma）。
  final double maxSigma;

  /// 从持久化的枚举名恢复；未知值回退到关闭。
  static LyricDistanceBlurLevel fromName(String? name) {
    if (name == null) return LyricDistanceBlurLevel.off;
    return LyricDistanceBlurLevel.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricDistanceBlurLevel.off,
    );
  }
}
