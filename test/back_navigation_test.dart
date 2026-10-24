import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/navigation/back_navigation.dart';

/// 「返回」的输入判定：鼠标侧键 / 浏览器后退键 / ⌘[。
///
/// 这里守的是**判定**与**分发**：真实设备 + remap 工具最终发哪一种，用
/// `test/demo/input_probe.dart` 实测（单测只能合成事件）。
void main() {
  KeyDownEvent down(LogicalKeyboardKey key) => KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyA,
    logicalKey: key,
    timeStamp: Duration.zero,
  );

  test('browserBack 算返回；browserForward / 裸 [ / 抬起都不算', () {
    expect(isBackKeyEvent(down(LogicalKeyboardKey.browserBack)), isTrue);
    expect(isBackKeyEvent(down(LogicalKeyboardKey.browserForward)), isFalse);
    expect(isBackKeyEvent(down(LogicalKeyboardKey.bracketLeft)), isFalse);
    expect(isBackKeyEvent(down(LogicalKeyboardKey.bracketRight)), isFalse);
    expect(
      isBackKeyEvent(
        KeyUpEvent(
          physicalKey: PhysicalKeyboardKey.keyA,
          logicalKey: LogicalKeyboardKey.browserBack,
          timeStamp: Duration.zero,
        ),
      ),
      isFalse,
    );
  });

  test('只有后腿位（0x08）算；前进位（0x10）与主键都不算', () {
    PointerDownEvent eventWith(int buttons) =>
        PointerDownEvent(buttons: buttons, position: Offset.zero);

    expect(isBackPointerEvent(eventWith(kBackMouseButton)), isTrue);
    expect(isBackPointerEvent(eventWith(kForwardMouseButton)), isFalse);
    expect(isBackPointerEvent(eventWith(kPrimaryMouseButton)), isFalse);
    // 后退与主键同时按住时仍然算（有些驱动会叠加）。
    expect(
      isBackPointerEvent(eventWith(kPrimaryMouseButton | kBackMouseButton)),
      isTrue,
    );
  });

  testWidgets('鼠标后退侧键弹一层路由；主键点击不弹', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    var backs = 0;
    final handler = BackNavigationHandler(
      onBack: () {
        backs++;
        popTopRoute(navKey.currentState);
      },
    );

    await tester.pumpWidget(
      Listener(
        onPointerDown: handler.handlePointerDown,
        child: MaterialApp(
          navigatorKey: navKey,
          home: const Scaffold(body: Text('root')),
        ),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('detail'), findsOneWidget);

    // 主键点击：不算返回。
    await tester.tap(find.text('detail'));
    await tester.pumpAndSettle();
    expect(backs, 0);
    expect(find.text('detail'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('detail')),
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(backs, 1);
    expect(find.text('detail'), findsNothing);
    expect(find.text('root'), findsOneWidget);
  });

  testWidgets('⌘[ 弹一层路由', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    var backs = 0;
    final handler = BackNavigationHandler(
      onBack: () {
        backs++;
        popTopRoute(navKey.currentState);
      },
    );
    FocusManager.instance.addLateKeyEventHandler(handler.handleKey);
    addTearDown(
      () => FocusManager.instance.removeLateKeyEventHandler(handler.handleKey),
    );

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('root')),
      ),
    );
    navKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('detail')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.metaLeft,
      platform: 'macos',
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.bracketLeft,
      platform: 'macos',
    );
    await tester.sendKeyUpEvent(
      LogicalKeyboardKey.bracketLeft,
      platform: 'macos',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft, platform: 'macos');
    await tester.pumpAndSettle();

    expect(backs, 1);
    expect(find.text('detail'), findsNothing);
  });

  testWidgets('已经在主界面时返回无动作（不崩、不切页）', (tester) async {
    final navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        home: const Scaffold(body: Text('root')),
      ),
    );

    expect(navKey.currentState!.canPop(), isFalse);
    popTopRoute(navKey.currentState);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('root'), findsOneWidget);
  });
}
