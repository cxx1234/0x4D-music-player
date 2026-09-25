import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/hud_service.dart';
import 'package:txvziwm/widgets/hud_overlay.dart';

const _volume = HudMessage(
  icon: Icons.volume_up_rounded,
  text: '40%',
  kind: HudKind.volume,
);

/// 真实挂载形态：底部居中，下方压着一层可点区域（验证不吃点击）。
Future<void> _pumpHud(
  WidgetTester tester,
  HudService hud, {
  bool enabled = true,
  VoidCallback? onTapBehind,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTapBehind,
                child: const SizedBox.expand(),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: HudOverlay(hud: hud, enabled: enabled),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// 走完入场/出场动画。
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('没有消息：不渲染任何内容', (tester) async {
    final hud = HudService();
    await _pumpHud(tester, hud);

    expect(find.text('40%'), findsNothing);
    expect(find.byIcon(Icons.volume_up_rounded), findsNothing);

    hud.dispose();
  });

  testWidgets('show / dismiss：出现与消失', (tester) async {
    final hud = HudService();
    await _pumpHud(tester, hud);

    hud.show(_volume);
    await _settle(tester);
    expect(find.text('40%'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);

    hud.dismiss();
    await _settle(tester);
    expect(find.text('40%'), findsNothing);

    hud.dispose();
  });

  testWidgets('同一种类连续更新：文本原地替换（不重启入场动画）', (tester) async {
    final hud = HudService();
    await _pumpHud(tester, hud);

    hud.show(_volume);
    await _settle(tester);

    hud.show(
      const HudMessage(
        icon: Icons.volume_down_rounded,
        text: '50%',
        kind: HudKind.volume,
      ),
    );
    await _settle(tester);

    expect(find.text('40%'), findsNothing);
    expect(find.text('50%'), findsOneWidget);

    hud.dispose();
  });

  testWidgets('enabled: false（正在播放页）不渲染，且消息到达即丢弃', (tester) async {
    final hud = HudService();
    await _pumpHud(tester, hud, enabled: false);

    hud.show(_volume);
    await _settle(tester);

    expect(find.text('40%'), findsNothing);
    expect(hud.message, isNull, reason: '丢弃而不是留着，离开该页时才不会延迟弹出');

    hud.dispose();
  });

  testWidgets('点击穿透：HUD 覆盖区域的点击仍落到下层控件', (tester) async {
    final hud = HudService();
    var taps = 0;
    await _pumpHud(tester, hud, onTapBehind: () => taps++);

    hud.show(_volume);
    await _settle(tester);
    expect(find.text('40%'), findsOneWidget);

    await tester.tap(find.text('40%'));
    expect(taps, 1, reason: 'HUD 必须 IgnorePointer，不能挡住底部区域的点击');

    hud.dispose();
  });
}
