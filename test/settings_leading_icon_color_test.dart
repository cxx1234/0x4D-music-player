import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';
import 'package:txvziwm/features/settings/settings_page.dart';

/// 「外观」分组里两行 leading 图标（主题模式 / 主题色）的着色回归。
///
/// 坑：这两行不是 ListTile（一行要放分段按钮、一行要横排色板圆点），自己拼的
/// `Row` 里放裸 `Icon`，拿不到 ListTile 那条 `iconColor = onSurfaceVariant` 的
/// 注入，于是退回 `ThemeData.iconTheme` 的固定纯黑/纯白（M2 遗留），
/// 和上下其它 leading 图标颜色对不上。这里断言两者**实际渲染色**一致。
void main() {
  /// 图标实际渲染用的颜色：`Icon.color` 优先，否则取祖先 `IconTheme`。
  Color? effectiveColor(WidgetTester tester, IconData data) {
    final finder = find.byIcon(data);
    expect(finder, findsOneWidget, reason: '未找到图标 $data');
    return tester.widget<Icon>(finder).color ??
        IconTheme.of(tester.element(finder)).color;
  }

  Future<void> pumpSettings(WidgetTester tester, Brightness brightness) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.monochrome(brightness: brightness),
        home: const Scaffold(body: SettingsPage()),
      ),
    );
  }

  testWidgets('浅色：主题模式 / 主题色图标与其它 leading 图标同色', (tester) async {
    await pumpSettings(tester, Brightness.light);

    // 参照物：「播放设置 › 续播上次播放位置」的 ListTile leading 图标。
    final reference = effectiveColor(tester, Icons.replay_rounded);
    expect(reference, isNotNull);

    expect(effectiveColor(tester, Icons.palette_outlined), reference);
    // 浅色主题下主题行显示太阳。
    expect(effectiveColor(tester, Icons.light_mode), reference);
  });

  testWidgets('深色：主题模式 / 主题色图标与其它 leading 图标同色', (tester) async {
    await pumpSettings(tester, Brightness.dark);

    final reference = effectiveColor(tester, Icons.replay_rounded);
    expect(reference, isNotNull);

    expect(effectiveColor(tester, Icons.palette_outlined), reference);
    // 深色主题下主题行显示月亮。
    expect(effectiveColor(tester, Icons.dark_mode), reference);
  });
}
