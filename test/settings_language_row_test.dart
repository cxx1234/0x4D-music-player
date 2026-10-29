import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';
import 'package:txvziwm/features/settings/settings_page.dart';

import 'helpers/l10n.dart';

/// 「语言」行的点击区回归。
///
/// 坑：`PopupMenuButton` 曾放在 `ListTile.trailing` 里，只有右侧箭头那一小块
/// 能点开菜单，行体是死的 —— 其它设置行都是整行点击。现在菜单按钮包在
/// `ListTile` 外层，整行（图标 / 文案 / 箭头）都能点开。
void main() {
  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.monochrome(brightness: Brightness.light),
        home: const Scaffold(body: SettingsPage()),
      ),
    );
  }

  testWidgets('点行内的标题文案即可展开语言菜单', (tester) async {
    await pumpSettings(tester);

    final title = find.text('语言');
    await tester.ensureVisible(title);
    await tester.pumpAndSettle();
    expect(find.text('English'), findsNothing);

    // 点在标题（行体）上，而不是右侧箭头。
    await tester.tap(title);
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
    expect(find.text('简体中文'), findsOneWidget);
  });

  testWidgets('点行内左侧图标也能展开语言菜单', (tester) async {
    await pumpSettings(tester);

    final icon = find.byIcon(Icons.language);
    await tester.ensureVisible(icon);
    await tester.pumpAndSettle();

    await tester.tap(icon);
    await tester.pumpAndSettle();

    expect(find.text('English'), findsOneWidget);
  });
}
