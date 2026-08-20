/// 歌词字号档位。
///
/// 与 [SongSortOrder] 同为「枚举自带 UI 文案放 core 层」的既有模式：
/// core 层的 [SettingsService] 需要存取该类型（歌词字号写盘持久化），
/// 因此不放在 features/player（避免 core → features 反向依赖）。
enum LyricTextSize {
  small('小', 0.85),
  medium('中', 1.0),
  large('大', 1.25);

  const LyricTextSize(this.label, this.scale);

  /// 菜单展示用的中文标签。
  final String label;

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
