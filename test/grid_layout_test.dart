import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/core/utils/grid_layout.dart';

SliverGridRegularTileLayout _layoutFor(
  double width, {
  double maxCrossAxisExtent = 200,
  int minCrossAxisCount = 2,
  int maxCrossAxisCount = 8,
  double crossAxisSpacing = 12,
}) {
  final delegate = SliverGridDelegateWithClampedExtent(
    maxCrossAxisExtent: maxCrossAxisExtent,
    minCrossAxisCount: minCrossAxisCount,
    maxCrossAxisCount: maxCrossAxisCount,
    mainAxisSpacing: 12,
    crossAxisSpacing: crossAxisSpacing,
    childAspectRatio: 0.76,
  );
  final layout = delegate.getLayout(
    SliverConstraints(
      axisDirection: AxisDirection.down,
      growthDirection: GrowthDirection.forward,
      userScrollDirection: ScrollDirection.idle,
      scrollOffset: 0,
      precedingScrollExtent: 0,
      overlap: 0,
      remainingPaintExtent: 1000,
      crossAxisExtent: width,
      crossAxisDirection: AxisDirection.right,
      viewportMainAxisExtent: 1000,
      remainingCacheExtent: 1000,
      cacheOrigin: 0,
    ),
  );
  return layout as SliverGridRegularTileLayout;
}

void main() {
  group('SliverGridDelegateWithClampedExtent', () {
    test('列数随宽度自适应且不溢出（回归：最右卡片被裁切）', () {
      // 手机 / 平板 / 桌面 / 4K 全屏，保证总宽 ≤ 可用宽度。
      final cases = <double>[
        358, // 手机内容宽
        500,
        736, // 平板
        900,
        1248, // 桌面
        1600,
        3808, // 4K
      ];
      for (final width in cases) {
        final layout = _layoutFor(width);
        final last = layout.getGeometryForChildIndex(layout.crossAxisCount - 1);
        expect(
          last.crossAxisOffset + last.crossAxisExtent,
          lessThanOrEqualTo(width + 0.001),
          reason: 'width=$width: 网格总宽不应超过可用宽度',
        );
      }
    });

    test('列数钳制在 [min, max] 之间', () {
      expect(_layoutFor(358).crossAxisCount, 2); // 手机 2 列
      expect(_layoutFor(736).crossAxisCount, 4); // 平板
      expect(_layoutFor(1248).crossAxisCount, 7);
      expect(_layoutFor(3808).crossAxisCount, 8); // 4K 封顶

      // 极窄窗口也不低于 2 列
      expect(_layoutFor(100).crossAxisCount, 2);
      // 超宽窗口不高于 8 列
      expect(_layoutFor(10000).crossAxisCount, 8);
    });

    test('扣除间距后格子铺满一行', () {
      const width = 358.0;
      final layout = _layoutFor(width);
      expect(layout.crossAxisCount, 2);
      final last = layout.getGeometryForChildIndex(1);
      // (358 - 12) / 2 = 173，最后一格右缘正好 358
      expect(last.crossAxisExtent, closeTo(173, 0.001));
      expect(last.crossAxisOffset + last.crossAxisExtent, closeTo(358, 0.001));
    });
  });
}
