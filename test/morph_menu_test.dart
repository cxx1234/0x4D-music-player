import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/widgets/morph_menu.dart';

/// 容器变换菜单的公共面板（睡眠定时入口 + 播放列表卡片共用）。
///
/// 这里守的是 `MenuMorphRoute` 那条硬约束：**面板宽高必须在打开之前算出来**
/// （终点矩形是算的，不能先布局再定位）。所以 `heightFor` / `widthFor` 与实际
/// 渲染尺寸必须一致，否则长出来的矩形会跳；宽度还得扛住最长的文案 —— 之前
/// 写死宽度 + 裸 `Row` 正是在「取消定时（1:30:00）」上溢出的。
void main() {
  /// 播放列表卡片那四项（没有分隔线，也没有勾选行）。
  const playlistEntries = <MorphMenuEntry<String>>[
    MorphMenuEntry('删除', 'delete'),
    MorphMenuEntry('重命名', 'rename'),
    MorphMenuEntry('导出', 'export'),
    MorphMenuEntry('播放', 'play'),
  ];

  /// 睡眠定时菜单里最长的一行（可勾选 + 计时中）。
  const longEntries = <MorphMenuEntry<String>>[
    MorphMenuEntry.checkable('播完当前曲目', 'endOfTrack', checked: true),
    MorphMenuEntry('取消定时（1:30:00）', 'cancel'),
  ];

  /// 渲染面板，并把 `widthFor` / `heightFor` 的预期值带出来做对比。
  Future<({Size actual, Size expected})> pumpPanel(
    WidgetTester tester,
    List<MorphMenuEntry<String>> entries, {
    Set<int> dividerAfter = const <int>{},
    ValueChanged<String>? onSelected,
  }) async {
    late Size expected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              final width = MorphMenuPanel.widthFor(context, entries);
              final height = MorphMenuPanel.heightFor(
                entries,
                dividerAfter: dividerAfter,
              );
              expected = Size(width, height);
              // 面板在路由里被摆成固定的锚定尺寸，这里照做。
              return SizedBox(
                width: width,
                height: height,
                child: MorphMenuPanel<String>(
                  entries: entries,
                  dividerAfter: dividerAfter,
                  onSelected: onSelected ?? (_) {},
                ),
              );
            },
          ),
        ),
      ),
    );
    return (
      actual: tester.getSize(find.byType(MorphMenuPanel<String>)),
      expected: expected,
    );
  }

  testWidgets('渲染出来的尺寸和 heightFor / widthFor 算出来的一致', (tester) async {
    final result = await pumpPanel(
      tester,
      playlistEntries,
      dividerAfter: const {1},
    );

    expect(result.actual, result.expected);
    // 4 行 × 48 + 1 条分隔线 × 8 + 上下内边距 16。
    expect(result.expected.height, 216);
  });

  testWidgets('每行一个文本，dividerAfter 决定分隔线条数', (tester) async {
    await pumpPanel(tester, playlistEntries);
    expect(find.byType(Divider), findsNothing);

    await pumpPanel(tester, playlistEntries, dividerAfter: const {0, 2});
    expect(find.text('播放'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(find.byType(Divider), findsNWidgets(2));
  });

  testWidgets('点中一行把该行的值回传出去', (tester) async {
    String? picked;
    await pumpPanel(
      tester,
      playlistEntries,
      onSelected: (value) => picked = value,
    );

    await tester.tap(find.text('重命名'));
    expect(picked, 'rename');

    await tester.tap(find.text('删除'));
    expect(picked, 'delete');
  });

  testWidgets('可勾选行画对勾（未勾选留透明占位），普通行不吃勾选位', (tester) async {
    const mixed = <MorphMenuEntry<String>>[
      MorphMenuEntry.checkable('播完当前曲目', 'endOfTrack', checked: true),
      MorphMenuEntry.checkable('播完当前播放列表', 'endOfQueue'),
      MorphMenuEntry('取消定时（4:59）', 'cancel'),
    ];
    await pumpPanel(tester, mixed);

    final checks = tester.widgetList<Icon>(find.byIcon(Icons.check)).toList();
    expect(checks, hasLength(2));
    expect(checks.first.color, isNot(Colors.transparent));
    // 未勾选的同类行用透明图标占位，行内文字不会左右跳。
    expect(checks.last.color, Colors.transparent);

    const indent =
        kMorphMenuPaddingX + kMorphMenuCheckWidth + kMorphMenuCheckGap;
    expect(tester.getTopLeft(find.text('播完当前曲目')).dx, indent);
    expect(tester.getTopLeft(find.text('播完当前播放列表')).dx, indent);
    // 普通行从内边距直接开始。分组排列 + 组间分隔线，参差的左边界读作「组内缩进」；
    // 而且它不再随「当前有没有勾选」左右漂移。
    expect(tester.getTopLeft(find.text('取消定时（4:59）')).dx, kMorphMenuPaddingX);
  });

  testWidgets('宽度两组分别取大，而不是「全表最宽 + 勾选位」', (tester) async {
    // 普通行更长时，勾选行不该把面板撑宽。
    const plainOnly = <MorphMenuEntry<String>>[
      MorphMenuEntry('重命名这个播放列表', 'a'),
      MorphMenuEntry('播放', 'b'),
    ];
    const mixplainWidest = <MorphMenuEntry<String>>[
      MorphMenuEntry('重命名这个播放列表', 'a'),
      MorphMenuEntry.checkable('播放', 'b'),
    ];
    // 同一串长文案，普通行 vs 可勾选行。
    const longPlain = <MorphMenuEntry<String>>[
      MorphMenuEntry('重命名', 'a'),
      MorphMenuEntry('播完当前播放列表', 'b'),
    ];
    const longCheckable = <MorphMenuEntry<String>>[
      MorphMenuEntry('重命名', 'a'),
      MorphMenuEntry.checkable('播完当前播放列表', 'b'),
    ];

    // 锚点宽度传 0 → 拿到的就是**没有被上下限夹过**的实测内容宽度，这样断言
    // 与字体度量无关。
    Future<double> contentWidth(List<MorphMenuEntry<String>> entries) async {
      late double width;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              width = MorphMenuPanel.widthForAnchor<String>(
                context,
                0,
                entries,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return width;
    }

    // 普通行最长 → 勾选位没有把它撑宽。
    expect(await contentWidth(mixplainWidest), await contentWidth(plainOnly));
    // 可勾选行最长 → 正好多一个勾选位。
    expect(
      await contentWidth(longCheckable) - await contentWidth(longPlain),
      kMorphMenuCheckWidth + kMorphMenuCheckGap,
    );
  });

  testWidgets('最长的文案（取消定时 1:30:00）不会溢出', (tester) async {
    // 溢出会以 FlutterError 的形式让这个用例直接失败，所以"能泵起来"就是结论。
    final result = await pumpPanel(tester, longEntries);

    expect(tester.takeException(), isNull);
    // 实测宽度必须大于下限：说明这个宽度是量出来的，不是写死的。
    expect(result.expected.width, greaterThan(kMorphMenuMinWidth));
  });

  testWidgets('widthForAnchor：宽度跟着锚点走，窄到放不下时以实测兜底', (tester) async {
    late double Function(double anchorWidth) measure;
    late double Function() content;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            measure = (anchorWidth) => MorphMenuPanel.widthForAnchor<String>(
              context,
              anchorWidth,
              playlistEntries,
            );
            // 锚点宽度传 0 → 拿到的是没被上下限夹过的实测内容宽度。
            content = () => MorphMenuPanel.widthForAnchor<String>(
              context,
              0,
              playlistEntries,
            );
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    // 卡片比内容宽 → 面板就是卡片的宽度（播放列表卡片走的就是这条）。
    expect(measure(240), 240);
    // 比 `kMorphMenuMinWidth` 还窄的卡片也给同样的宽度：宽度是锚点说了算，
    // 那个下限只管「没人给宽度」的情况。
    expect(measure(160), 160);
    // 窄到装不下最长一行时以实测宽度兜底，不让行里出现省略号。
    expect(measure(content() - 10), content());
    // 超宽锚点仍然夹在上限内。
    expect(measure(600), kMorphMenuMaxWidth);
  });

  testWidgets('宽度按最宽一行增长，并夹在上限内', (tester) async {
    // 每次都给一个能拿到 context 的完整树，借它量宽度。
    Future<double> measure(List<MorphMenuEntry<String>> entries) async {
      late double width;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              width = MorphMenuPanel.widthFor<String>(context, entries);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return width;
    }

    final shortWidth = await measure(playlistEntries);
    final longWidth = await measure(longEntries);
    final hugeWidth = await measure(const [
      MorphMenuEntry('这一行故意长到超过面板宽度上限，用来确认它是被夹住的', 'huge'),
    ]);

    expect(shortWidth, kMorphMenuMinWidth);
    expect(longWidth, greaterThan(shortWidth));
    expect(hugeWidth, kMorphMenuMaxWidth);
  });
}
