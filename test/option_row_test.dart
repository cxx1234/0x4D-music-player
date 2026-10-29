import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/app/theme.dart';
import 'package:txvziwm/features/settings/widgets/option_row.dart';

/// `OptionRow` 的行高 / 内边距 / 右对齐契约。
///
/// 这三条各对应一次已经发生过的 bug：行高 71 vs 72、右内边距 16 vs 24、
/// `Flexible` 里的 trailing 默认贴份额左缘。
void main() {
  final theme = AppTheme.monochrome(brightness: Brightness.light);

  Widget app(Widget child, {double width = 600}) {
    return MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  testWidgets('行高 72、左内边距 16、trailing 右缘贴 end 24', (tester) async {
    await tester.pumpWidget(
      app(
        OptionRow(
          icon: Icons.tune_rounded,
          title: '标题',
          subtitle: '副标题',
          trailing: const SizedBox(key: Key('t'), width: 40, height: 20),
        ),
      ),
    );

    final row = tester.getRect(find.byType(OptionRow));
    expect(row.height, OptionRow.kHeight);

    // leading 图标左缘 = 行内 start 内边距，颜色由组件统一注入。
    final icon = tester.getRect(find.byIcon(Icons.tune_rounded));
    expect(icon.left - row.left, OptionRow.kPadding.start);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.tune_rounded)).color,
      theme.colorScheme.onSurfaceVariant,
    );

    // 窄 trailing 必须靠右，而不是留在 Flexible 份额的左缘。
    final trailing = tester.getRect(find.byKey(const Key('t')));
    expect(trailing.right, moreOrLessEquals(row.right - 24, epsilon: 0.5));
  });

  testWidgets('ShrinkableTrailing 超过上限时等比缩小到上限', (tester) async {
    await tester.pumpWidget(
      app(
        OptionRow(
          icon: Icons.tune_rounded,
          title: '标题',
          subtitle: '副标题',
          trailing: const ShrinkableTrailing(
            maxWidth: 100,
            child: SizedBox(key: Key('t'), width: 300, height: 20),
          ),
        ),
      ),
    );

    final box = tester.getRect(find.byType(ShrinkableTrailing));
    expect(box.width, moreOrLessEquals(100, epsilon: 0.5));

    // 缩放后仍然贴右内缘。
    final row = tester.getRect(find.byType(OptionRow));
    expect(box.right, moreOrLessEquals(row.right - 24, epsilon: 0.5));
  });

  testWidgets('右槽优先拿固有宽度，但文字区不会被挤到保底宽度以下', (tester) async {
    await tester.pumpWidget(
      app(
        OptionRow(
          icon: Icons.tune_rounded,
          title: '标题',
          subtitle: '副标题',
          // 固有宽度 > 「行内宽度 - 48 - 保底文字宽」，会被压到文字区保底值。
          trailing: const ShrinkableTrailing(
            child: SizedBox(key: Key('t'), width: 1000, height: 20),
          ),
        ),
      ),
    );

    final row = tester.getRect(find.byType(OptionRow));
    final text = tester.getRect(find.byType(OptionRowText));
    expect(text.width, greaterThanOrEqualTo(OptionRow.kMinTextWidth - 0.5));
    expect(
      tester.getRect(find.byKey(const Key('t'))).right,
      moreOrLessEquals(row.right - 24, epsilon: 0.5),
    );
  });

  testWidgets('标题/副标题字号与设置行约定一致', (tester) async {
    await tester.pumpWidget(
      app(
        OptionRow(
          icon: Icons.tune_rounded,
          title: '标题',
          subtitle: '副标题',
          trailing: const SizedBox(width: 40, height: 20),
        ),
      ),
    );

    // 用实际解析后的主题取值（AppTheme 的 TextTheme 可能没写字号）。
    final resolved = Theme.of(tester.element(find.byType(OptionRow)));
    final title = tester.widget<Text>(find.text('标题'));
    expect(title.style?.fontSize, resolved.textTheme.titleMedium?.fontSize);
    final subtitle = tester.widget<Text>(find.text('副标题'));
    expect(subtitle.style?.fontSize, 11);
    expect(subtitle.style?.color, resolved.colorScheme.onSurfaceVariant);
    expect(subtitle.maxLines, 1);
  });
}
