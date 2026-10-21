/// 歌词逐字跳动（Word Pop）的幅度。
///
/// 两档只改跳起的高度，到位时间固定为 [liftDuration]。
enum LyricEffectStrength {
  standard('默认', 3.5),
  strong('强', 5);

  const LyricEffectStrength(this.label, this.lift);

  /// 逐字跳动到位的时间。
  static const Duration liftDuration = Duration(milliseconds: 900);

  /// 菜单/分段按钮展示用的中文标签。
  final String label;

  /// 逐字跳起的保持高度（逻辑像素）。
  final double lift;

  /// 从持久化的枚举名恢复；未知值回退到默认档。
  static LyricEffectStrength fromName(String? name) {
    if (name == null) return LyricEffectStrength.standard;
    return LyricEffectStrength.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricEffectStrength.standard,
    );
  }
}
