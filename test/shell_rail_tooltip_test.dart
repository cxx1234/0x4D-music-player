import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// shell_page.dart 一并导出 shell_controller.dart（NavigationItem / ShellController）。
import 'package:txvziwm/features/shell/shell_page.dart';

import 'helpers/l10n.dart';

/// 左侧导航栏的 tooltip 回归。
///
/// 侧栏用 `NavigationRailLabelType.selected`：只有选中项显示文字，其余 4 个是
/// 纯图标，靠 tooltip 给名字。`NavigationRail` 没有内置 tooltip，所以这里锁两件事：
/// 未选中项有 tooltip、选中项没有；切 tab 后随之翻转。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 侧栏里所有 tooltip 的文案。
  List<String> railTooltips(WidgetTester tester) => tester
      .widgetList<Tooltip>(
        find.descendant(
          of: find.byType(NavigationRail),
          matching: find.byType(Tooltip),
        ),
      )
      .map((tooltip) => tooltip.message!)
      .toList();

  Future<ShellController> pumpShell(WidgetTester tester) async {
    final controller = ShellController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      localizedApp(home: ShellPage(controller: controller)),
    );
    return controller;
  }

  testWidgets('未选中的四个入口带 tooltip，选中项不带', (tester) async {
    await pumpShell(tester);

    // 5 个入口里「音乐库」是初始选中项 → 只有其余 4 个有 tooltip。
    final tooltips = railTooltips(tester);
    expect(tooltips, hasLength(NavigationItem.values.length - 1));
    expect(tooltips, isNot(contains('音乐库')));
    expect(tooltips, containsAll(['专辑', '歌手', '播放列表', '设置']));

    // 读屏靠 destination 的 label，tooltip 不要再重复一遍。
    final first = tester
        .widgetList<Tooltip>(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.byType(Tooltip),
          ),
        )
        .first;
    expect(first.excludeFromSemantics, isTrue);
  });

  testWidgets('切 tab 后 tooltip 随之翻转', (tester) async {
    final controller = await pumpShell(tester);

    // 切到「设置」：该页不依赖 ServiceLocator，可在裸 Shell 里构建。
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationRail),
        matching: find.byIcon(Icons.settings),
      ),
    );
    await tester.pumpAndSettle();
    expect(controller.tab.value, NavigationItem.settings);

    final tooltips = railTooltips(tester);
    expect(tooltips, hasLength(NavigationItem.values.length - 1));
    expect(tooltips, isNot(contains('设置')));
    expect(tooltips, contains('音乐库'));
  });
}
