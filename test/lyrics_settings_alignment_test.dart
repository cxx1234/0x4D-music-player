import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';
import 'package:txvziwm/features/settings/lyrics_settings_page.dart';
import 'package:txvziwm/features/settings/widgets/option_row.dart';

import 'helpers/l10n.dart';

/// 歌词设置页里 `OptionRow`（分段按钮行）与 `ListTile` 行的右缘对齐回归。
///
/// 坑：这些行最初都是自拼 `Row` + `symmetric(horizontal: 16)`，而 M3
/// `ListTile` 默认是 `start: 16, end: 24`，于是分段按钮行比开关行右凸 8px。
void main() {
  testWidgets('分段按钮行与 ListTile 行 trailing 同处 end 24 内缘', (tester) async {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      localizedApp(
        theme: AppTheme.monochrome(brightness: Brightness.light),
        home: const LyricsSettingsPage(),
      ),
    );

    // 参照物：ListTile 行的右缘（卡片左右各 24）+ M3 默认 end 24。
    final tile = tester.getRect(find.byType(ListTile).first);
    final rail = tile.right - 24;

    final buttons = find
        .byWidgetPredicate((widget) => widget is SegmentedButton)
        .evaluate()
        .toList();
    expect(buttons, isNotEmpty, reason: '未找到分段按钮');
    for (final element in buttons) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.right, moreOrLessEquals(rail, epsilon: 0.5));
    }

    // 行高也与 ListTile 行一致。
    for (final element in find.byType(OptionRow).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.height, OptionRow.kHeight);
    }
  });
}
