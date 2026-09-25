import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/hud_service.dart';

const _volume = HudMessage(
  icon: Icons.volume_up_rounded,
  text: '40%',
  kind: HudKind.volume,
);

void main() {
  testWidgets('show：立即显示，默认时长到点自动隐藏', (tester) async {
    final hud = HudService();
    var notifications = 0;
    hud.addListener(() => notifications++);

    hud.show(_volume);
    expect(hud.message?.text, '40%');
    expect(notifications, 1);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(hud.message, isNotNull, reason: '未到 1200ms 不该消失');

    await tester.pump(const Duration(milliseconds: 200));
    expect(hud.message, isNull);
    expect(notifications, 2, reason: '显示 + 自动隐藏各通知一次');

    hud.dispose();
  });

  testWidgets('连续 show：原地换内容并重新计时（不提前消失）', (tester) async {
    final hud = HudService();

    hud.show(_volume);
    await tester.pump(const Duration(milliseconds: 1100));
    // 第二次按键：距第一次不足 1200ms，若不重新计时就会立刻消失。
    hud.show(
      const HudMessage(
        icon: Icons.volume_off_rounded,
        text: '0%',
        kind: HudKind.volume,
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));

    expect(hud.message?.text, '0%', reason: '仍在提示期内');

    await tester.pump(const Duration(milliseconds: 200));
    expect(hud.message, isNull);

    hud.dispose();
  });

  testWidgets('dismiss：立即隐藏，重复调用无副作用', (tester) async {
    final hud = HudService();
    hud.show(_volume, duration: const Duration(seconds: 10));

    hud.dismiss();
    expect(hud.message, isNull);

    hud.dismiss();
    expect(hud.message, isNull);

    // 手动隐藏后，原计时器必须已被取消（否则这里会因野 Timer 触发第二次通知）。
    await tester.pump(const Duration(seconds: 11));
    expect(hud.message, isNull);

    hud.dispose();
  });

  testWidgets('dispose 取消计时器，不留下野 Timer', (tester) async {
    final hud = HudService();
    hud.show(_volume, duration: const Duration(seconds: 5));
    hud.dispose();

    // 未取消的话这里会炸：dispose 后 notifyListeners 会抛。
    await tester.pump(const Duration(seconds: 6));
  });
}
