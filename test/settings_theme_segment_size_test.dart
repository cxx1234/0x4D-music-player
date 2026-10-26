import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';
import 'package:txvziwm/features/settings/settings_page.dart';
import 'package:txvziwm/features/settings/widgets/option_row.dart';

import 'helpers/l10n.dart';

/// 「主题模式」分段按钮在英文界面下不能被等比缩小。
///
/// 坑：原来是「文字区/右槽各占一半 + 右槽硬性上限 360」，英文标签
/// （"Follow system" / "Light" / "Dark"）固有宽度超过 360，`FittedBox.scaleDown`
/// 把整个按钮（含字号）缩到 ~0.8，肉眼就是文字比中文小两号。现在右槽优先拿
/// 固有宽度，只有文字区要跌破 [OptionRow.kMinTextWidth] 时才缩。
void main() {
  Future<void> pumpSettings(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedApp(
        locale: locale,
        theme: AppTheme.monochrome(brightness: Brightness.light),
        home: const Scaffold(body: SettingsPage()),
      ),
    );
  }

  testWidgets('英文：宽窗口下分段按钮保持自然尺寸', (tester) async {
    await pumpSettings(tester, const Locale('en'));

    final seg = tester.getRect(find.byType(SegmentedButton<ThemeMode>));
    // M3 分段按钮自然高度 40（测试字体下为 48）；被等比缩小后高度会成比例下降
    // （旧实现这里是 24.3）。用高度判定「有没有被缩」不受标签宽度影响。
    expect(seg.height, greaterThanOrEqualTo(40));

    // 文字区仍保留保底宽度，不会被右槽吃光。
    final text = tester.getRect(find.byType(OptionRowText).first);
    expect(text.width, greaterThanOrEqualTo(OptionRow.kMinTextWidth - 0.5));
  });

  testWidgets('中文：宽窗口下同样保持自然尺寸', (tester) async {
    await pumpSettings(tester, const Locale('zh'));

    final seg = tester.getRect(find.byType(SegmentedButton<ThemeMode>));
    expect(seg.height, greaterThanOrEqualTo(40));
  });
}
