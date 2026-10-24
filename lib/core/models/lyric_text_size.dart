/// 歌词字号档位。
///
/// 展示文案见 `lib/l10n/enum_labels.dart`。
enum LyricTextSize {
  small(1.0),
  medium(1.25),
  large(1.5);

  const LyricTextSize(this.scale);

  /// 相对基准字号的缩放比例。
  final double scale;

  /// 从持久化的枚举名恢复；未知值回退到默认 [LyricTextSize.medium]。
  static LyricTextSize fromName(String? name) {
    if (name == null) return LyricTextSize.medium;
    return LyricTextSize.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricTextSize.medium,
    );
  }
}
