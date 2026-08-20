import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/features/player/queue_view.dart';

void main() {
  group('isQueueItemInView', () {
    const extent = 72.0;
    const viewport = 600.0;

    test('完全在视口内 → 可见', () {
      expect(
        isQueueItemInView(
          index: 2,
          itemExtent: extent,
          pixels: 0,
          viewportDimension: viewport,
        ),
        isTrue,
      );
    });

    test('部分露出底部边缘 → 可见', () {
      // index 8: [576, 648)，视口 [0, 600) → 部分露出底部。
      expect(
        isQueueItemInView(
          index: 8,
          itemExtent: extent,
          pixels: 0,
          viewportDimension: viewport,
        ),
        isTrue,
      );
    });

    test('完全在下方视口外 → 不可见', () {
      // index 9: top=648 >= 600 → 完全在下方。
      expect(
        isQueueItemInView(
          index: 9,
          itemExtent: extent,
          pixels: 0,
          viewportDimension: viewport,
        ),
        isFalse,
      );
    });

    test('部分露出顶部边缘 → 可见', () {
      // index 1: [72, 144)，视口 [72, 672) → 顶部边缘恰好接触。
      expect(
        isQueueItemInView(
          index: 1,
          itemExtent: extent,
          pixels: 72,
          viewportDimension: viewport,
        ),
        isTrue,
      );
    });

    test('完全在上方视口外 → 不可见', () {
      // index 1: bottom=144 <= pixels=144 → 完全在上方。
      expect(
        isQueueItemInView(
          index: 1,
          itemExtent: extent,
          pixels: 144,
          viewportDimension: viewport,
        ),
        isFalse,
      );
    });
  });
}
