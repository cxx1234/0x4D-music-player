import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/features/settings/about_page.dart';
import 'package:txvziwm/features/settings/settings_page.dart';
import 'package:txvziwm/features/shell/shell_controller.dart';

/// 菜单「关于本软件」→ 设置 › 关于页 的导航链路。
///
/// 链路是：原生菜单 → `MenuService.openAbout`（app.dart 注入）→
/// `ShellController.request(settings, action: openAbout)` → 设置页订阅广播执行 push。
/// 这里只覆盖最后一段（前面几段分别在 menu_service_test 与 app.dart 里）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('收到 openAbout 动作：设置页推入关于页', (tester) async {
    final controller = ShellController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsPage(controller: controller)),
      ),
    );
    expect(find.byType(AboutPage), findsNothing);

    controller.request(NavigationItem.settings, action: ShellAction.openAbout);
    await tester.pump(); // postFrame 回调 → 广播动作
    await tester.pumpAndSettle();

    expect(find.byType(AboutPage), findsOneWidget);
  });

  testWidgets('没有 controller 时也不炸（设置页可独立构建）', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SettingsPage())),
    );
    expect(find.byType(AboutPage), findsNothing);
  });
}
