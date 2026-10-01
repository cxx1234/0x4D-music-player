import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/widgets/context_menu.dart';
import 'package:txvziwm/widgets/morph_menu.dart';

/// 右键菜单的公共入口（`context_menu.dart`）：
/// - 锚点换算（[overlayRectOf]）必须现取、且拿不到 RenderBox 时安静返回 null；
/// - 行尾槽位（[rowMenuSlot]）必须与 `SongTile` 三点按钮**同位置**，否则同一个
///   行用右键和用鼠标点三点会弹在两个地方；
/// - 两个入口都要把选中值原样回传给 `await` 的一方。
void main() {
  test('rowMenuSlot：贴住行右内缘、与行同高居中，尺寸等于三点按钮命中区', () {
    const row = Rect.fromLTWH(16, 100, 400, 72);
    final slot = rowMenuSlot(row);

    expect(slot.size, const Size(kRowMenuSlotSize, kRowMenuSlotSize));
    // ListTile 自己的水平内边距是 16，按钮贴在它的内缘。
    expect(slot.right, row.right - 16);
    expect(slot.center.dy, row.center.dy);
  });

  testWidgets('overlayRectOf 取到控件自己的矩形（overlay 坐标）', (tester) async {
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox(width: 200, height: 100);
              },
            ),
          ),
        ),
      ),
    );

    // 布局完成后才取：build 阶段 RenderBox 还没有尺寸（那时返回 null 是对的）。
    final rect = overlayRectOf(captured);
    if (rect == null) fail('取不到控件矩形');
    expect(rect.width, 200);
    expect(rect.height, 100);
    // 测试窗口里 overlay 就在原点，坐标应与全局坐标一致。
    expect(rect.topLeft.dx, closeTo(0, 0.01));
    expect(rect.topLeft.dy, closeTo(0, 0.01));
  });

  testWidgets('Sliver 的 itemBuilder context 拿不到行矩形 → 返回 null（不抛类型错）', (
    tester,
  ) async {
    Rect? fromItemBuilder;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  // 这个 context 解析到的是 RenderSliver*，不是 RenderBox。
                  fromItemBuilder = overlayRectOf(context);
                  return const SizedBox(height: 72, child: Text('row'));
                }, childCount: 1),
              ),
            ],
          ),
        ),
      ),
    );

    expect(fromItemBuilder, isNull);
  });

  testWidgets('showRowMenu 用标准弹出菜单（与三点按钮同一套）并回传选中值', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => SizedBox(
                width: 400,
                height: 72,
                child: TextButton(
                  onPressed: () async {
                    picked = await showRowMenu<String>(
                      context: context,
                      rowRect: overlayRectOf(context)!,
                      entries: const [
                        PopupMenuItem(value: 'remove', child: Text('从队列移除')),
                      ],
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // 行状条目走的是标准弹出菜单，不是容器变换面板。
    expect(find.byType(MorphMenuPanel<String>), findsNothing);
    expect(find.byType(PopupMenuItem<String>), findsOneWidget);
    expect(find.text('从队列移除'), findsOneWidget);

    await tester.tap(find.text('从队列移除'));
    await tester.pumpAndSettle();
    expect(picked, 'remove');
    expect(find.text('从队列移除'), findsNothing);
  });

  testWidgets('showCardMenu 从卡片底边弹出面板并把选中值回传', (tester) async {
    String? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Builder(
              builder: (context) => SizedBox(
                width: 200,
                height: 240,
                child: TextButton(
                  onPressed: () async {
                    picked = await showCardMenu<String>(
                      context: context,
                      cardRect: overlayRectOf(context)!,
                      entries: const [
                        MorphMenuEntry('添加到播放队列', 'queue'),
                        MorphMenuEntry('播放全部', 'play'),
                      ],
                    );
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(MorphMenuPanel<String>), findsOneWidget);
    expect(find.text('播放全部'), findsOneWidget);

    await tester.tap(find.text('播放全部'));
    await tester.pumpAndSettle();
    expect(picked, 'play');
  });
}
