import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';
import 'package:txvziwm/features/settings/settings_page.dart';

import 'helpers/l10n.dart';

/// 「外观」分组里自拼行（主题模式 / 主题色）的右缘对齐回归。
///
/// 两个坑：
/// 1. 主题模式行是自拼 `Row`（图标 + 文案 + 分段按钮），按钮放在 `Flexible` 里；
///    `Flexible` 只给「剩余宽度的份额」并默认左对齐，宽窗口下按钮贴在份额左缘，
///    右侧空一大块。
/// 2. 自拼行的内边距曾写成 `symmetric(horizontal: 16)`，而 M3 `ListTile` 默认是
///    **非对称**的 `start: 16, end: 24`，于是自拼行比所有 ListTile 行右凸 8px。
///
/// 这里同时断言：分段按钮、圆点色板、ListTile 行 trailing 三者右缘重合。
void main() {
  testWidgets('宽窗口：自拼行右缘与 ListTile 行 trailing 内缘重合', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.monochrome(brightness: Brightness.light),
        home: const Scaffold(body: SettingsPage()),
      ),
    );

    // 参照物：ListTile 行的 trailing（「歌词显示」行的 chevron）。
    final rail = tester.getRect(find.byIcon(Icons.chevron_right).first).right;

    // 主题色行：最后一个圆点（色板右对齐到内缘）。
    final card = find.ancestor(
      of: find.byIcon(Icons.palette_outlined),
      matching: find.byType(Card),
    );
    final dots = find.descendant(of: card, matching: find.byType(Tooltip));
    final lastDot = tester.getRect(find.byWidget(dots.evaluate().last.widget));

    final segmented = tester.getRect(find.byType(SegmentedButton<ThemeMode>));

    expect(segmented.right, moreOrLessEquals(rail, epsilon: 0.5));
    expect(lastDot.right, moreOrLessEquals(rail, epsilon: 0.5));
  });
}
