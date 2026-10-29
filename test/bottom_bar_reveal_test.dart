import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/widgets/bottom_bar_reveal.dart';

void main() {
  group('BottomBarReveal.revealHeight', () {
    const viewport = 800.0;

    test('起点就是底栏高度（页面用自己的带子盖住底栏原位置）', () {
      expect(BottomBarReveal.revealHeight(0, viewport), 64);
    });

    test('带子在前 1/3 进度内长满，且一开始就在动', () {
      // 兜底带高 140：0.35 时早已超过 → 带子段在前期就完成，没有分段停顿。
      expect(BottomBarReveal.revealHeight(0.35, viewport), greaterThan(140));
      // 进度刚起步就在动（不是"先等 30% 再开始"）。
      expect(BottomBarReveal.revealHeight(0.05, viewport), greaterThan(64));
    });

    test('带内内容不透明度：只在开头/结尾很短一段里变化', () {
      expect(BottomBarReveal.bandContentOpacity(0), 0);
      // 短窗口内就吃满 —— 否则收起时"按钮先淡掉、卡片还没收完"。
      expect(BottomBarReveal.bandContentOpacity(0.02), lessThan(1));
      expect(
        BottomBarReveal.bandContentOpacity(BottomBarReveal.bandFadePhase),
        1,
      );
      expect(BottomBarReveal.bandContentOpacity(0.5), 1);
      expect(BottomBarReveal.bandContentOpacity(1), 1);
    });

    test('卡片顶边细线：收起态与终点都不画，中途随进度加深', () {
      final scheme = ColorScheme.dark();
      // 收起态必须没有（否则会和迷你底栏对不上）。
      expect(BottomBarReveal.hairlineColor(scheme, 0), isNull);
      // 终点也不画（顶边已经在窗口顶）。
      expect(BottomBarReveal.hairlineColor(scheme, 1), isNull);
      // 中途存在且随进度加深。
      final early = BottomBarReveal.hairlineColor(scheme, 0.2)!;
      final late = BottomBarReveal.hairlineColor(scheme, 0.8)!;
      expect(late.a, greaterThan(early.a));
    });

    test('整体微缩放：带子阶段 0.97，结束时 1', () {
      expect(BottomBarReveal.pageScaleFor(0), 0.97);
      expect(BottomBarReveal.pageScaleFor(BottomBarReveal.bandPhase), 0.97);
      expect(BottomBarReveal.pageScaleFor(1), closeTo(1, 1e-9));

      var last = 0.0;
      for (var i = 0; i <= 40; i++) {
        final value = BottomBarReveal.pageScaleFor(i / 40);
        expect(value, greaterThanOrEqualTo(last));
        last = value;
      }
    });

    test('卡片顶角：收起态为 0（与底栏直边一致），前 40% 进度内吃到满值', () {
      expect(BottomBarReveal.cornerRadiusFor(0), 0);
      expect(
        BottomBarReveal.cornerRadiusFor(0.4),
        BottomBarReveal.maxCornerRadius,
      );
      expect(
        BottomBarReveal.cornerRadiusFor(1),
        BottomBarReveal.maxCornerRadius,
      );

      var last = -1.0;
      for (var i = 0; i <= 40; i++) {
        final value = BottomBarReveal.cornerRadiusFor(i / 40);
        expect(value, greaterThanOrEqualTo(last));
        last = value;
      }
    });

    test('卡片投影：收起态无投影，进度越大越明显', () {
      expect(BottomBarReveal.surfaceShadow(ColorScheme.light(), 0), isEmpty);
      final early = BottomBarReveal.surfaceShadow(ColorScheme.light(), 0.2);
      final late = BottomBarReveal.surfaceShadow(ColorScheme.light(), 0.8);
      expect(early, isNotEmpty);
      expect(late.first.color.a, greaterThan(early.first.color.a));
      // 0 blur 实线（仓库约定：不触发 Impeller 的 SDF blur）。
      expect(late.every((s) => s.blurRadius == 0), isTrue);
      // 方向朝上（卡片压在页面上方）。
      expect(late.every((s) => s.offset.dy < 0), isTrue);
    });

    test('正文整体上浮：进度 0 时下移 contentLift，进度 1 归位', () {
      expect(BottomBarReveal.contentLiftFor(0), BottomBarReveal.contentLift);
      expect(BottomBarReveal.contentLiftFor(1), 0);

      var last = double.infinity;
      for (var i = 0; i <= 40; i++) {
        final value = BottomBarReveal.contentLiftFor(i / 40);
        expect(value, lessThanOrEqualTo(last));
        last = value;
      }
    });

    test('收起箭头只在收尾段（0.8 → 1）翻转', () {
      // 顶栏还没露出来的时段：保持朝上，不动。
      expect(BottomBarReveal.collapseArrowTurns(0), 0.5);
      expect(BottomBarReveal.collapseArrowTurns(0.5), 0.5);
      expect(BottomBarReveal.collapseArrowTurns(0.8), 0.5);
      // 收尾段转到位。
      expect(BottomBarReveal.collapseArrowTurns(1), closeTo(0, 1e-6));

      var last = double.infinity;
      for (var i = 80; i <= 100; i++) {
        final value = BottomBarReveal.collapseArrowTurns(i / 100);
        expect(value, lessThanOrEqualTo(last));
        last = value;
      }
    });

    test('结束铺满，且全程单调不减', () {
      expect(BottomBarReveal.revealHeight(1, viewport), viewport);

      var last = -1.0;
      for (var i = 0; i <= 40; i++) {
        final value = BottomBarReveal.revealHeight(i / 40, viewport);
        expect(value, greaterThanOrEqualTo(last));
        last = value;
      }
    });

    test('视口比带子还矮时不超过视口', () {
      expect(BottomBarReveal.revealHeight(1, 100), 100);
      expect(BottomBarReveal.revealHeight(0.5, 100), lessThanOrEqualTo(100));
    });
  });

  group('BottomBarReveal 几何', () {
    const size = Size(1000, 800);

    Future<void> setUpView(WidgetTester tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Future<void> pumpAt(WidgetTester tester, double progress) {
      return tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BottomBarReveal(
            animation: AlwaysStoppedAnimation<double>(progress),
            child: const SizedBox.expand(key: Key('page')),
          ),
        ),
      );
    }

    testWidgets('裁剪窗口随进度长高，页面始终按全屏高度布局（不重排）', (tester) async {
      await setUpView(tester);

      // 起点：窗口高度 64（正是底栏），页面已经在树上（挂载后不再销毁/重建）。
      await pumpAt(tester, 0);
      expect(tester.getSize(find.byType(ClipRect)), const Size(1000, 64));
      expect(tester.getSize(find.byKey(const Key('page'))), size);

      // 带子阶段中途。
      await pumpAt(tester, 0.3);
      final mid = tester.getSize(find.byType(ClipRect)).height;
      expect(mid, greaterThan(64));
      expect(mid, lessThan(size.height));
      expect(tester.getSize(find.byKey(const Key('page'))), size);

      // 结束：铺满。
      await pumpAt(tester, 1);
      expect(tester.getSize(find.byType(ClipRect)), size);
    });

    testWidgets('量到真实带高后，带子垫底按真实带高走（不是兜底 140）', (tester) async {
      await setUpView(tester);
      final bandKey = GlobalKey();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: BottomBarReveal(
            animation: const AlwaysStoppedAnimation<double>(1),
            bandKey: bandKey,
            child: Column(
              children: [
                const Expanded(child: SizedBox()),
                SizedBox(key: bandKey, height: 180),
              ],
            ),
          ),
        ),
      );

      // 首帧后量到带高并重建：垫底两块里第二块（带子色）高度 = 实测带高。
      await tester.pump();
      final bandStrip = find.byType(ColoredBox).at(1);
      expect(tester.getSize(bandStrip).height, closeTo(180, 0.01));
    });
  });
}
