import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/core/utils/keyboard_focus.dart';

/// 键盘导航（Tab）焦点的退出口回归测试（2026-09-23）。
///
/// 覆盖 `lib/core/utils/keyboard_focus.dart` + `app.dart` 的接线方式：
/// - Tab 进入键盘导航后，Esc 取消焦点，空格不再激活「看不见的」聚焦按钮；
/// - Esc 不劫持对话框 / 弹层菜单（它们是 late handler 之前的处理者）；
/// - 点空白处也能取消焦点，且不影响按钮自身的点击。

/// 模拟 app.dart 的注册方式（late key handler），并统计「被本处理器消费」的次数。
void _attachEscapeHandler(List<int> handled) {
  KeyEventResult handler(KeyEvent event) {
    final result = handleKeyboardFocusKeyEvent(event);
    if (result == KeyEventResult.handled) handled[0]++;
    return result;
  }

  FocusManager.instance.addLateKeyEventHandler(handler);
  addTearDown(() => FocusManager.instance.removeLateKeyEventHandler(handler));
}

/// 与 `app.dart` 根 Scaffold 同构：body 外包 translucent 的根级 GestureDetector。
Widget _harness({required VoidCallback onPress, Widget? extra}) {
  return MaterialApp(
    home: Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => clearKeyboardFocus(),
        child: Column(
          children: [
            ElevatedButton(onPressed: onPress, child: const Text('button')),
            ?extra,
            const Expanded(child: SizedBox.expand()),
          ],
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Tab 聚焦后 Esc 取消焦点，空格不再激活该按钮', (tester) async {
    var presses = 0;
    final handled = <int>[0];
    _attachEscapeHandler(handled);

    await tester.pumpWidget(_harness(onPress: () => presses++));

    // 启动时只有路由自身的 FocusScope 持有焦点 → 不算键盘导航。
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());
    expect(hasKeyboardFocus, isFalse);

    // Tab 进入键盘导航（跳过路由 Scope，落到真实控件上）。
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hasKeyboardFocus, isTrue);

    // 空格激活聚焦控件（框架默认 ActivateIntent，与 Enter 一致）。
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(presses, 1);

    // Esc 取消焦点：处理器介入一次，焦点回到路由 Scope。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(handled[0], 1);
    expect(hasKeyboardFocus, isFalse);
    expect(FocusManager.instance.primaryFocus, isA<FocusScopeNode>());

    // 关键回归：没有聚焦控件后，空格不再触发任何按钮。
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(presses, 1);

    // 再次 Tab 仍可重新进入键盘导航（Esc 只是退出，不是禁用）。
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hasKeyboardFocus, isTrue);
  });

  testWidgets('Esc 不劫持对话框：对话框自行关闭，处理器不介入', (tester) async {
    final handled = <int>[0];
    _attachEscapeHandler(handled);

    await tester.pumpWidget(
      _harness(
        onPress: () {},
        extra: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const AlertDialog(title: Text('dialog')),
            ),
            child: const Text('open dialog'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('dialog'), findsNothing);
    expect(handled[0], 0);
  });

  testWidgets('Esc 不劫持弹层菜单：菜单自行关闭，处理器不介入', (tester) async {
    final handled = <int>[0];
    _attachEscapeHandler(handled);

    await tester.pumpWidget(
      _harness(
        onPress: () {},
        extra: PopupMenuButton<String>(
          itemBuilder: (_) => const <PopupMenuEntry<String>>[
            PopupMenuItem<String>(value: 'x', child: Text('item')),
          ],
          child: const Text('menu'),
        ),
      ),
    );

    await tester.tap(find.text('menu'));
    await tester.pumpAndSettle();
    expect(find.text('item'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('item'), findsNothing);
    expect(handled[0], 0);
  });

  testWidgets('点空白处取消焦点，点按钮不受影响', (tester) async {
    var presses = 0;
    final handled = <int>[0];
    _attachEscapeHandler(handled);

    await tester.pumpWidget(_harness(onPress: () => presses++));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(hasKeyboardFocus, isTrue);

    // 点按钮：按钮自己的手势赢下手势竞技场 → 根级兜底不触发、点击照常生效。
    await tester.tap(find.text('button'));
    await tester.pump();
    expect(presses, 1);

    // 点空白处：没人竞争 → 根级兜底取消焦点。
    await tester.tapAt(const Offset(400, 500));
    await tester.pump();
    expect(hasKeyboardFocus, isFalse);

    // 点空白处不消费键盘事件（不占用 late handler 的额度）。
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(handled[0], 0);
  });
}
