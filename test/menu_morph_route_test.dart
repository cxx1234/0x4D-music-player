import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/widgets/menu_morph_route.dart';

/// `MenuMorphRoute` 的几何：生长方向、顶部安全区、屏幕钳制。
///
/// 这些数都是**打开之前算好**的终点矩形，出错时的症状很具体 —— 面板顶到窗口
/// 上沿（macOS 上会钻进红绿灯），或者本该向上长开却往下掉。都是曾经真的出过的
/// 问题，所以在这里钉住。
void main() {
  const panel = Size(150, 120);
  const contentKey = Key('menu-content');

  /// 在 [viewport] 大小的窗口里从 [anchorRect] 打开一张 [panelSize] 的面板，
  /// 返回稳定后的内容矩形（= 路由算出的终点矩形）。
  Future<Rect> openRoute(
    WidgetTester tester, {
    required Rect anchorRect,
    MenuMorphGrow grow = MenuMorphGrow.auto,
    double topInset = 0,
    Size panelSize = panel,
    Size viewport = const Size(400, 400),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewport;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MenuMorphRoute<String>(
                  anchorRect: anchorRect,
                  panelSize: panelSize,
                  grow: grow,
                  topInset: topInset,
                  builder: (context, close) =>
                      const SizedBox.expand(key: contentKey),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return tester.getRect(find.byKey(contentKey));
  }

  testWidgets('grow: up 把底边钉在锚点底边（下方空间充足也向上长）', (tester) async {
    final rect = await openRoute(
      tester,
      anchorRect: const Rect.fromLTWH(20, 200, 100, 20),
      grow: MenuMorphGrow.up,
    );

    expect(rect.left, 20);
    expect(rect.bottom, 220); // 锚点底边
    expect(rect.top, 100); // 220 - 面板高
  });

  testWidgets('grow: auto 在同一位置则向下长（对照）', (tester) async {
    final rect = await openRoute(
      tester,
      anchorRect: const Rect.fromLTWH(20, 200, 100, 20),
    );

    expect(rect.top, 200); // 锚点顶边
    expect(rect.bottom, 320);
  });

  testWidgets('首选方向装不下就翻到另一个方向', (tester) async {
    // 锚点贴顶：上方只剩 80，装不下 120 的面板；下方很空 → 翻成向下。
    final rect = await openRoute(
      tester,
      anchorRect: const Rect.fromLTWH(20, 80, 100, 20),
      grow: MenuMorphGrow.up,
    );

    expect(rect.top, 80);
  });

  testWidgets('向上生长时顶边停在顶部安全区下方（红绿灯那一栏）', (tester) async {
    // 面板比上方空间高 → 高度被钳制，顶边停在「安全区 + 8」，靠面板内部滚动消化。
    // 不扣安全区的话这里会是 8 —— 正好钻进原生红绿灯底下。
    const inset = 52.0;
    final rect = await openRoute(
      tester,
      anchorRect: const Rect.fromLTWH(20, 360, 100, 20),
      grow: MenuMorphGrow.up,
      topInset: inset,
      panelSize: const Size(150, 400),
    );

    expect(rect.top, inset + 8);
    expect(rect.bottom, 380); // 底边仍然钉在锚点底边
    expect(rect.height, 320); // = 380 - 60
  });
}
