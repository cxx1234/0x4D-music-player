import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/app.dart';
import 'package:txvziwm/features/player/player_page.dart';

void main() {
  testWidgets('播放页上方再压页面时底栏保持隐藏', (tester) async {
    final showBar = ValueNotifier<bool>(true);
    addTearDown(showBar.dispose);
    final navKey = GlobalKey<NavigatorState>();
    final observer = NowPlayingBarVisibilityObserver(showBar);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navKey,
        navigatorObservers: [observer],
        home: const Scaffold(body: Text('shell')),
      ),
    );
    expect(showBar.value, isTrue);

    navKey.currentState!.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: PlayerPage.routeName),
        builder: (_) => const Scaffold(body: Text('player')),
      ),
    );
    await tester.pumpAndSettle();
    expect(showBar.value, isFalse);

    // 从播放页打开的歌词设置：栈顶不是 PlayerPage，但底栏必须继续隐藏。
    navKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Text('lyrics settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(showBar.value, isFalse);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(showBar.value, isFalse);

    navKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(showBar.value, isTrue);
  });
}
