import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/widgets/index_scrollbar.dart';

void main() {
  Widget wrap({
    required int itemCount,
    String? Function(int index)? letterOfIndex,
  }) {
    final controller = ScrollController();
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: IndexScrollbar(
            controller: controller,
            itemCount: itemCount,
            itemExtent: 72,
            letterOfIndex: letterOfIndex ?? (index) => 'A',
            child: ListView.builder(
              controller: controller,
              itemExtent: 72,
              itemCount: itemCount,
              itemBuilder: (_, index) =>
                  SizedBox(height: 72, child: Text('row $index')),
            ),
          ),
        ),
      ),
    );
  }

  /// 轨道命中区位于最右侧 14px（width 400 → x ∈ [386, 400]）。
  const trackX = 393.0;

  Future<void> makeTrackVisible(WidgetTester tester) async {
    // 先在列表区域（非轨道）滚动，触发滑块 overlay 显示。
    await tester.dragFrom(const Offset(200, 300), const Offset(0, -60));
    await tester.pump();
  }

  testWidgets('拖动轨道时显示索引字母气泡', (tester) async {
    await tester.pumpWidget(wrap(itemCount: 100));
    await makeTrackVisible(tester);

    // 在轨道上按下并拖动。
    await tester.dragFrom(Offset(trackX, 100), const Offset(0, 80));
    await tester.pump();

    expect(find.text('A'), findsOneWidget, reason: '拖动滑块时应弹出索引字母气泡');

    // 推进时间让隐藏 Timer / 淡出动画完成，避免 pending timer。
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('letterOfIndex 返回 null 时不显示气泡（纯普通滑块）', (tester) async {
    await tester.pumpWidget(wrap(itemCount: 100, letterOfIndex: (_) => null));
    await makeTrackVisible(tester);

    await tester.dragFrom(Offset(trackX, 100), const Offset(0, 80));
    await tester.pump();

    expect(find.textContaining('A'), findsNothing, reason: '无字母概念时拖动滑块不弹气泡');

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('气泡跟随拖动位置更新字母', (tester) async {
    var currentLetter = 'A';
    await tester.pumpWidget(
      wrap(
        itemCount: 200,
        letterOfIndex: (index) {
          // 前 50 行 'A'，之后 'Z'，用于验证拖动到不同位置字母变化。
          currentLetter = index < 50 ? 'A' : 'Z';
          return currentLetter;
        },
      ),
    );
    await makeTrackVisible(tester);

    // 拖到轨道底部：滚动 offset 接近 max → index 应 > 50 → 'Z'。
    await tester.dragFrom(Offset(trackX, 100), const Offset(0, 300));
    await tester.pump();
    expect(find.text('Z'), findsOneWidget, reason: '拖到底部应显示 Z');

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('滚动列表时滑块跟随移动', (tester) async {
    await tester.pumpWidget(wrap(itemCount: 100));
    await makeTrackVisible(tester);

    final thumbFinder = find.byKey(const ValueKey('index-scrollbar-thumb'));
    expect(thumbFinder, findsOneWidget, reason: '滚动后滑块应可见');

    final top1 = tester.getTopLeft(thumbFinder).dy;
    // 继续向下滚动列表（滚轮/拖拽等价，都走 controller 通知）。
    await tester.dragFrom(const Offset(200, 300), const Offset(0, -120));
    await tester.pump();
    final top2 = tester.getTopLeft(thumbFinder).dy;

    expect(top2, isNot(equals(top1)), reason: '滚动后滑块位置应更新');

    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('hover 轨道时滑块加宽（hover 效果稳定）', (tester) async {
    await tester.pumpWidget(wrap(itemCount: 100));
    await makeTrackVisible(tester);

    final thumbFinder = find.descendant(
      of: find.byKey(const ValueKey('index-scrollbar-thumb')),
      matching: find.byType(AnimatedContainer),
    );
    final before = tester.getSize(thumbFinder).width;

    // 用鼠标指针 hover 轨道。
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset(trackX, 200));
    addTearDown(gesture.removePointer);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200)); // 完成加宽动画

    final after = tester.getSize(thumbFinder).width;
    expect(after, greaterThan(before), reason: 'hover 后滑块应变宽');

    // 移出轨道 → 宽度恢复。
    await gesture.moveTo(const Offset(200, 200));
    await tester.pump(); // 先调度 move 事件，触发 onExit + setState
    await tester.pump(const Duration(milliseconds: 200)); // 完成宽度动画
    expect(tester.getSize(thumbFinder).width, before, reason: '移出后滑块应恢复原宽');

    await tester.pump(const Duration(seconds: 2));
  });
}
