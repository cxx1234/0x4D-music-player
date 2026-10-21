/// 歌词切句动画风格。
///
/// 只暴露少数几个稳定的内置轨迹；更多参数留在库内部，避免设置页变成调参器。
enum LyricLineTransitionStyle {
  classic('经典', '默认的尺寸过渡'),
  scale('缩放', '放大后微微收束'),
  slide('滑入', '从下方滑入并淡入'),
  none('无', '立即切换，不做动画');

  const LyricLineTransitionStyle(this.label, this.description);

  /// 菜单展示用的中文标签。
  final String label;

  /// 副标题里的效果说明。
  final String description;

  /// 从持久化的枚举名恢复；未知值回退到经典。
  static LyricLineTransitionStyle fromName(String? name) {
    if (name == null) return LyricLineTransitionStyle.classic;
    return LyricLineTransitionStyle.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricLineTransitionStyle.classic,
    );
  }
}
