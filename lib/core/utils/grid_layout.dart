import 'package:flutter/rendering.dart';

/// 结合原生 [SliverGridDelegateWithMaxCrossAxisExtent] 思路与显式列数上下限的
/// 自适应网格 delegate。
///
/// 列数 = ceil(可用宽度 / [maxCrossAxisExtent])，再钳制到
/// [[minCrossAxisCount], [maxCrossAxisCount]]。相比手写断点表：无需
/// LayoutBuilder，列数随窗口平滑变化且上下限天然保证。
class SliverGridDelegateWithClampedExtent extends SliverGridDelegate {
  const SliverGridDelegateWithClampedExtent({
    this.maxCrossAxisExtent = 200,
    this.minCrossAxisCount = 2,
    this.maxCrossAxisCount = 8,
    this.mainAxisSpacing = 0,
    this.crossAxisSpacing = 0,
    this.childAspectRatio = 1,
  }) : assert(maxCrossAxisExtent > 0),
       assert(minCrossAxisCount > 0),
       assert(maxCrossAxisCount >= minCrossAxisCount);

  /// 每格目标最大宽度（横轴）。列数由它反推并夹紧在上下限之间。
  final double maxCrossAxisExtent;

  /// 列数下限，防止窄窗口把格子排得过密（如手机保底 2 列）。
  final int minCrossAxisCount;

  /// 列数上限，防止超宽窗口列数无限增长。
  final int maxCrossAxisCount;

  /// 主轴（行）方向间距。
  final double mainAxisSpacing;

  /// 横轴（列）方向间距。
  final double crossAxisSpacing;

  /// 每格宽高比（宽 / 高）。
  final double childAspectRatio;

  @override
  SliverGridLayout getLayout(SliverConstraints constraints) {
    final crossAxisCount = (constraints.crossAxisExtent / maxCrossAxisExtent)
        .ceil()
        .clamp(minCrossAxisCount, maxCrossAxisCount)
        .toInt();
    // 先扣除列间距再平分，否则总宽度会超出可用宽度，最右一列被裁掉。
    final tileCrossAxisExtent =
        (constraints.crossAxisExtent -
            crossAxisSpacing * (crossAxisCount - 1)) /
        crossAxisCount;
    final tileMainAxisExtent = tileCrossAxisExtent / childAspectRatio;
    return SliverGridRegularTileLayout(
      crossAxisCount: crossAxisCount,
      mainAxisStride: tileMainAxisExtent + mainAxisSpacing,
      crossAxisStride: tileCrossAxisExtent + crossAxisSpacing,
      childMainAxisExtent: tileMainAxisExtent,
      childCrossAxisExtent: tileCrossAxisExtent,
      reverseCrossAxis: axisDirectionIsReversed(constraints.crossAxisDirection),
    );
  }

  @override
  bool shouldRelayout(SliverGridDelegateWithClampedExtent oldDelegate) {
    return oldDelegate.maxCrossAxisExtent != maxCrossAxisExtent ||
        oldDelegate.minCrossAxisCount != minCrossAxisCount ||
        oldDelegate.maxCrossAxisCount != maxCrossAxisCount ||
        oldDelegate.mainAxisSpacing != mainAxisSpacing ||
        oldDelegate.crossAxisSpacing != crossAxisSpacing ||
        oldDelegate.childAspectRatio != childAspectRatio;
  }
}
