import 'package:flutter/material.dart';

/// 卡片表面：无 blur 的「3 条实线底部投影」+ 可选水波。
///
/// 替代 `Card(elevation: N)` —— Material elevation 阴影在 Impeller 的 macOS
/// SDF 路径上开销高（尤其弱 GPU / Intel）；`blurRadius: 0` 的 BoxShadow 是纯色
/// 填充，不触发 blur shader，弱 GPU 上也近乎零成本。
///
/// 内部结构：
/// ```
/// Container(
///   clipBehavior: Clip.hardEdge,
///   decoration: BoxDecoration(color, borderRadius, boxShadow: 3条实线),
///   child: Material(type: transparency, child: InkWell(child)),
/// )
/// ```
/// `Material(type: transparency)` 让 InkWell 的墨迹能画在卡片表面之上（与
/// `Card` + `InkWell` 的行为一致），同时不遮挡 `Container` 绘制的底部投影。
class CardSurface extends StatelessWidget {
  const CardSurface({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderRadius = 12,
    this.showShadow = true,
  });

  /// 卡片内容。
  final Widget child;

  /// 点击回调（可选；提供了才包 `InkWell`）。
  final VoidCallback? onTap;

  /// 长按回调（可选）。
  final VoidCallback? onLongPress;

  /// 卡片底色；默认 `surfaceContainerLow`（比页面表面高一档）。
  final Color? color;

  /// 圆角。
  final double borderRadius;

  /// 是否绘制底部投影；关闭则纯平面。
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: showShadow ? bottomDropShadow(scheme) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: (onTap != null || onLongPress != null)
            ? InkWell(onTap: onTap, onLongPress: onLongPress, child: child)
            : child,
      ),
    );
  }
}

/// 3 条无 blur 实线底部投影：偏移 (0,1)/(0,2)/(0,3)、透明度递减。
///
/// `blurRadius: 0` → 纯色填充，不触发 Impeller 的 SDF blur。
/// 颜色用 [ColorScheme.shadow]，暗色模式自动适配。
List<BoxShadow> bottomDropShadow(ColorScheme scheme) {
  final shadow = scheme.shadow;
  return [
    BoxShadow(
      color: shadow.withValues(alpha: 0.10),
      blurRadius: 0,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: shadow.withValues(alpha: 0.07),
      blurRadius: 0,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: shadow.withValues(alpha: 0.04),
      blurRadius: 0,
      offset: const Offset(0, 3),
    ),
  ];
}
