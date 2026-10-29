import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';
import 'package:txvziwm/features/settings/settings_page.dart';

import 'helpers/l10n.dart';

/// 缓存行「清理」按钮的淡描边回归。
///
/// 它是行尾的次要动作，没有描边时看着像一段可点击文字；描边用
/// `outlineVariant`（与页面其它细线同色），不用 M3 `OutlinedButton` 默认的
/// `outline`，也不要改尺寸（行内会被撑宽）。
void main() {
  testWidgets('「清理」按钮有 outlineVariant 描边', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final theme = AppTheme.monochrome(brightness: Brightness.light);
    await tester.pumpWidget(
      localizedApp(
        theme: theme,
        home: const Scaffold(body: SettingsPage()),
      ),
    );

    // 分段按钮内部也是 TextButton，按图标定位这一个。
    final button = tester.widget<TextButton>(
      find.ancestor(
        of: find.byIcon(Icons.cleaning_services),
        matching: find.byType(TextButton),
      ),
    );
    expect(
      button.style?.side?.resolve(<WidgetState>{}),
      BorderSide(color: theme.colorScheme.outlineVariant),
    );
  });
}
