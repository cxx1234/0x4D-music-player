import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import 'package:txvziwm/core/models/lyric_load_state.dart';
import 'package:txvziwm/core/models/lyric_text_size.dart';
import 'package:txvziwm/features/player/lyrics_view.dart';
import 'package:txvziwm/features/player/player_ui_state.dart';

import 'helpers/l10n.dart';

Widget _wrap(Widget child) => localizedApp(
  home: Scaffold(body: SizedBox(width: 400, height: 400, child: child)),
);

void main() {
  testWidgets('无歌词：显示占位 + 菜单栏（含文本大小按钮）', (tester) async {
    final controller = LyricController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        LyricsView(
          controller: controller,
          theme: ThemeData(),
          uiState: PlayerUiState(),
        ),
      ),
    );

    // 菜单栏：左文本 + 文本大小按钮；未传回调时没有设置入口。
    expect(find.text('歌词'), findsOneWidget);
    expect(find.byIcon(Icons.text_fields_rounded), findsOneWidget);
    expect(find.byTooltip('歌词显示设置'), findsNothing);
    // 无歌词 → 占位，不渲染 LyricView。
    expect(find.text('暂无歌词'), findsOneWidget);
    expect(find.byType(LyricView), findsNothing);
  });

  testWidgets('歌词加载中：显示进度，不显示「暂无歌词」', (tester) async {
    final controller = LyricController();
    final loadState = ValueNotifier<LyricLoadState>(LyricLoadState.loading);
    addTearDown(controller.dispose);
    addTearDown(loadState.dispose);

    await tester.pumpWidget(
      _wrap(
        LyricsView(
          controller: controller,
          theme: ThemeData(),
          uiState: PlayerUiState(),
          loadState: loadState,
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('暂无歌词'), findsNothing);

    loadState.value = LyricLoadState.empty;
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('暂无歌词'), findsOneWidget);
  });

  testWidgets('有歌词：渲染 LyricView，不显示占位', (tester) async {
    final controller = LyricController()..load('[00:01.00]第一行\n[00:05.00]第二行');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _wrap(
        LyricsView(
          controller: controller,
          theme: ThemeData(),
          uiState: PlayerUiState(),
        ),
      ),
    );

    expect(find.byType(LyricView), findsOneWidget);
    expect(find.text('暂无歌词'), findsNothing);
  });

  testWidgets('文档切换：重建 LyricView，避免沿用旧会话', (tester) async {
    final controller = LyricController()..load('[00:01.00]第一行');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _wrap(
        LyricsView(
          controller: controller,
          theme: ThemeData(),
          uiState: PlayerUiState(),
        ),
      ),
    );

    final before = tester.state(find.byType(LyricView));
    controller.load('[00:01.00]第二首');
    await tester.pump();
    final after = tester.state(find.byType(LyricView));

    expect(identical(before, after), isFalse);
  });

  testWidgets('点文本大小 → 弹三档菜单 → 选择"大"写入 uiState', (tester) async {
    final controller = LyricController();
    addTearDown(controller.dispose);
    final uiState = PlayerUiState();
    await tester.pumpWidget(
      _wrap(
        LyricsView(
          controller: controller,
          theme: ThemeData(),
          uiState: uiState,
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.text_fields_rounded));
    await tester.pumpAndSettle();

    expect(find.text('小'), findsOneWidget);
    expect(find.text('中'), findsOneWidget);
    expect(find.text('大'), findsOneWidget);

    await tester.tap(find.text('大'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(uiState.lyricTextSize, LyricTextSize.large);
  });

  testWidgets('翻译开关：点击翻转 uiState 并触发回调', (tester) async {
    final controller = LyricController();
    addTearDown(controller.dispose);
    final uiState = PlayerUiState();
    var toggled = 0;
    await tester.pumpWidget(
      _wrap(
        LyricsView(
          controller: controller,
          theme: ThemeData(),
          uiState: uiState,
          onToggleTranslation: () => toggled++,
        ),
      ),
    );

    // 默认开启 → 菜单栏有翻译开关按钮。
    expect(uiState.showTranslation, isTrue);
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pump();

    expect(uiState.showTranslation, isFalse);
    expect(toggled, 1);
  });

  testWidgets('设置按钮：点击触发打开歌词显示设置', (tester) async {
    final controller = LyricController();
    addTearDown(controller.dispose);
    var opened = false;
    await tester.pumpWidget(
      _wrap(
        LyricsView(
          controller: controller,
          theme: ThemeData(),
          uiState: PlayerUiState(),
          onOpenSettings: () => opened = true,
        ),
      ),
    );

    expect(find.byTooltip('歌词显示设置'), findsOneWidget);
    await tester.tap(find.byTooltip('歌词显示设置'));
    expect(opened, isTrue);
  });

  testWidgets('歌词滚动条只在鼠标位于歌词卡片上时显示', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final controller = LyricController()
        ..load('[00:01.00]第一行\n[00:05.00]第二行');
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _wrap(
          LyricsView(
            controller: controller,
            theme: ThemeData(),
            uiState: PlayerUiState(),
          ),
        ),
      );
      await tester.pump();

      Scrollbar scrollbar() => tester.widget<Scrollbar>(find.byType(Scrollbar));
      ScrollbarTheme scrollbarTheme() =>
          tester.widget<ScrollbarTheme>(find.byType(ScrollbarTheme));
      // 不悬停：滑块不可见且透明（程序化滚动淡入也不会闪）。
      expect(scrollbar().thumbVisibility, isFalse);
      expect(
        scrollbarTheme().data.thumbColor?.resolve(const {}),
        Colors.transparent,
      );

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.byType(LyricView)));
      await tester.pump();
      // 悬停：恢复主题色并常显。
      expect(scrollbar().thumbVisibility, isTrue);
      expect(scrollbarTheme().data.thumbColor, isNull);

      // 移出 400×400 的歌词卡片（Scaffold 默认 800×600）。
      await gesture.moveTo(const Offset(600, 500));
      await tester.pump();
      expect(scrollbar().thumbVisibility, isFalse);
      expect(
        scrollbarTheme().data.thumbColor?.resolve(const {}),
        Colors.transparent,
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
