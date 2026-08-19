import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/core/services/play_queue.dart';

/// PlayQueue 写盘防抖/串行链测试。
///
/// 测试环境下 `getApplicationDocumentsDirectory()` 无插件实现会抛
/// MissingPluginException，被 `_saveToJson` 的 try/catch 吞掉——因此这里
/// 主要验证 flush API 不抛异常、串行链正常完成（真实写盘行为在应用中验证）。
void main() {
  group('PlayQueue 写盘防抖与 flush', () {
    test('变更后 flushPendingSave 立即落盘且不抛异常', () async {
      final q = PlayQueue();
      // 触发两次 _save()（防抖窗口内应合并为一次写）。
      q.setRepeatModeName('all');
      q.setIsShuffled(true);
      // 立即 flush：跳过防抖等待，返回的 Future 应正常完成。
      await q.flushPendingSave();
      expect(q.repeatModeName, 'all');
      expect(q.isShuffled, isTrue);
    });

    test('无待写变更时 flush 直接返回完成链', () async {
      final q = PlayQueue();
      await q.flushPendingSave();
      expect(q.isEmpty, isTrue);
    });

    test('串行写链：连续多次变更 + 多次 flush 不乱序抛错', () async {
      final q = PlayQueue();
      q.setRepeatModeName('one');
      final f1 = q.flushPendingSave();
      q.setIsShuffled(false);
      final f2 = q.flushPendingSave();
      await Future.wait([f1, f2]);
      expect(q.repeatModeName, 'one');
      expect(q.isShuffled, isFalse);
    });

    test('防抖定时器触发后 flush 不会重复写', () async {
      final q = PlayQueue();
      q.setRepeatModeName('all');
      // 等待防抖窗口（500ms）过后，定时器已消费待写标记。
      await Future<void>.delayed(const Duration(milliseconds: 600));
      // 此时没有待写变更，flush 应为 no-op（不抛）。
      await q.flushPendingSave();
      expect(q.repeatModeName, 'all');
    });
  });
}
