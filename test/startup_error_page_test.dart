import 'package:flutter/material.dart';
import 'package:flutter_music/app/startup_error_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('启动错误页显示错误摘要并可触发重试', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StartupErrorPage(
          error: StateError('boom'),
          onRetry: () => retried = true,
        ),
      ),
    );

    // 标题、错误摘要、两个按钮都在
    expect(find.text('应用启动失败'), findsOneWidget);
    expect(find.textContaining('Bad state: boom'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('复制错误详情'), findsOneWidget);

    // 点击重试触发回调
    await tester.tap(find.text('重试'));
    expect(retried, isTrue);
  });
}
