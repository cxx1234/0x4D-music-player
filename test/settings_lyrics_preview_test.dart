import 'package:flutter/material.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/models/lyric_distance_blur_level.dart';
import 'package:txvziwm/core/models/lyric_effect_strength.dart';
import 'package:txvziwm/core/models/lyric_line_transition_style.dart';
import 'package:txvziwm/features/settings/lyrics_preview.dart';
import 'package:txvziwm/features/settings/lyrics_settings_page.dart';

import 'helpers/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(localizedApp(home: const LyricsSettingsPage()));
    await tester.pump();
  }

  testWidgets('宽屏：显示循环预览，位置随时间推进', (tester) async {
    await pumpPage(tester, const Size(1000, 800));

    expect(find.byType(LyricsPreview), findsOneWidget);
    final view = tester.widget<LyricView>(find.byType(LyricView));
    final before = view.controller.position;

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(view.controller.position, greaterThan(before));
  });

  testWidgets('窄屏：只显示设置项，不构建预览', (tester) async {
    await pumpPage(tester, const Size(600, 800));

    expect(find.byType(LyricsPreview), findsNothing);
    expect(find.byType(LyricView), findsNothing);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('翻译副行'), findsOneWidget);
  });

  testWidgets('切字号立即改变预览的 preset', (tester) async {
    await pumpPage(tester, const Size(1000, 800));

    final before = tester
        .widget<LyricView>(find.byType(LyricView))
        .preset!
        .activeTextStyle
        .fontSize;

    await tester.tap(find.text('大'));
    await tester.pump();

    final after = tester
        .widget<LyricView>(find.byType(LyricView))
        .preset!
        .activeTextStyle
        .fontSize;
    expect(after, isNot(before));
    expect(after, closeTo(16 * 1.5 * 1.2, 0.01));
  });

  testWidgets('关翻译后预览文档立即去掉副行', (tester) async {
    await pumpPage(tester, const Size(1000, 800));

    final controller = tester
        .widget<LyricView>(find.byType(LyricView))
        .controller;
    expect(controller.document!.lines.first.translation, isNotNull);

    await tester.tap(find.text('翻译副行'));
    await tester.pump();

    expect(controller.document!.lines.first.translation, isNull);
  });

  testWidgets('逐字填充开关写入预览的 preset', (tester) async {
    await pumpPage(tester, const Size(1000, 900));

    LyricView view() => tester.widget<LyricView>(find.byType(LyricView));
    expect(view().preset!.highlight.enabled, isTrue);
    expect(view().preset!.wordEffects.simulateTiming, isTrue);

    await tester.tap(find.text('逐字填充'));
    await tester.pump();

    expect(view().preset!.highlight.enabled, isFalse);
    expect(view().preset!.wordEffects.simulateTiming, isFalse);
  });

  testWidgets('逐字跳动与强度写入预览的 preset', (tester) async {
    await pumpPage(tester, const Size(1000, 900));

    LyricView view() => tester.widget<LyricView>(find.byType(LyricView));

    await tester.tap(find.text('逐字跳动'));
    await tester.pump();
    var effects = view().preset!.wordEffects;
    expect(effects.lift, 3.5);
    expect(effects.liftDuration, const Duration(milliseconds: 900));
    expect(effects.simulateTiming, isTrue);
    expect(effects.floatAmplitude, 0);

    final strengthButton = find.byType(SegmentedButton<LyricEffectStrength>);
    await tester.tap(
      find.descendant(of: strengthButton, matching: find.text('强')),
    );
    await tester.pump();
    effects = view().preset!.wordEffects;
    expect(effects.lift, 5);

    await tester.tap(
      find.descendant(of: strengthButton, matching: find.text('默认')),
    );
    await tester.pump();
    effects = view().preset!.wordEffects;
    expect(effects.lift, 3.5);
  });

  testWidgets('滑入可选左/右对齐，方向跟随对齐边', (tester) async {
    await pumpPage(tester, const Size(1000, 900));

    LyricView view() => tester.widget<LyricView>(find.byType(LyricView));
    Future<void> tapTransition(String label) async {
      await tester.tap(find.widgetWithText(ListTile, '切句动画'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(
        find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate(
            (widget) => widget is PopupMenuItem<LyricLineTransitionStyle>,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await tapTransition('滑入');
    var preset = view().preset!;
    expect(preset.textAlign, TextAlign.left);
    expect(preset.contentAlignment, LyricContentAlignment.start);
    expect(preset.padding, const EdgeInsets.symmetric(horizontal: 44));
    expect(preset.lineTransition.state(false).offset, const Offset(-24, 8));

    await tester.tap(find.text('右'));
    await tester.pump();
    preset = view().preset!;
    expect(preset.textAlign, TextAlign.right);
    expect(preset.contentAlignment, LyricContentAlignment.end);
    expect(preset.padding, const EdgeInsets.symmetric(horizontal: 44));
    expect(preset.lineTransition.state(false).offset, const Offset(24, 8));
  });

  testWidgets('倒计时圆点开关写入预览的 preset', (tester) async {
    await pumpPage(tester, const Size(1000, 1200));

    LyricView view() => tester.widget<LyricView>(find.byType(LyricView));
    expect(view().preset!.countdown.enabled, isTrue);

    await tester.ensureVisible(find.text('倒计时圆点'));
    await tester.pump();
    await tester.tap(find.text('倒计时圆点'));
    await tester.pump();

    expect(view().preset!.countdown.enabled, isFalse);
  });

  testWidgets('距离模糊档位写入预览的 preset', (tester) async {
    await pumpPage(tester, const Size(1000, 1100));

    LyricView view() => tester.widget<LyricView>(find.byType(LyricView));
    expect(view().preset!.distanceBlur.maxSigma, 0);

    final segmented = find.byType(SegmentedButton<LyricDistanceBlurLevel>);
    await tester.ensureVisible(segmented);
    await tester.pump();
    await tester.tap(find.descendant(of: segmented, matching: find.text('标准')));
    await tester.pump();

    var blur = view().preset!.distanceBlur;
    expect(blur.maxSigma, 4);
    expect(blur.sigmaPerLine, 1);
    expect(blur.whenBrowsing, isFalse);

    await tester.tap(find.descendant(of: segmented, matching: find.text('关')));
    await tester.pump();
    blur = view().preset!.distanceBlur;
    expect(blur.maxSigma, 0);
  });

  testWidgets('行间波浪写入预览的 preset', (tester) async {
    await pumpPage(tester, const Size(1000, 1000));

    LyricView view() => tester.widget<LyricView>(find.byType(LyricView));
    expect(view().preset!.lineMotion.waveAmplitude, 0);

    await tester.ensureVisible(find.text('行间波浪'));
    await tester.pump();
    await tester.tap(find.text('行间波浪'));
    await tester.pump();

    final motion = view().preset!.lineMotion;
    expect(motion.delay, const Duration(milliseconds: 35));
    expect(motion.maxDelay, const Duration(milliseconds: 140));
    expect(motion.waveDuration, const Duration(milliseconds: 600));
    expect(motion.waveAmplitude, 12);
    expect(motion.maxLag, 64);
  });

  testWidgets('切句动画选择写入预览的 preset', (tester) async {
    await pumpPage(tester, const Size(1000, 900));

    LyricView view() => tester.widget<LyricView>(find.byType(LyricView));
    expect(
      view().preset!.lineTransition.enterDuration,
      const Duration(milliseconds: 200),
    );

    await tester.tap(find.widgetWithText(ListTile, '切句动画'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // 文字本身不参与命中测试，点它所在的菜单项。
    await tester.tap(
      find.ancestor(
        of: find.text('缩放'),
        matching: find.byWidgetPredicate(
          (widget) => widget is PopupMenuItem<LyricLineTransitionStyle>,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      view().preset!.lineTransition.enterDuration,
      const Duration(milliseconds: 500),
    );
  });
}
