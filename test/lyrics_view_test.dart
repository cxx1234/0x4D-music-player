import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lyric/flutter_lyric.dart';

import 'package:flutter_music/features/player/lyrics_view.dart';
import 'package:flutter_music/features/player/player_ui_state.dart';

Widget _wrap(Widget child) => MaterialApp(
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

    // 菜单栏：左文本 + 文本大小按钮。
    expect(find.text('歌词'), findsOneWidget);
    expect(find.byIcon(Icons.text_fields_rounded), findsOneWidget);
    // 无歌词 → 占位，不渲染 LyricView。
    expect(find.text('暂无歌词'), findsOneWidget);
    expect(find.byType(LyricView), findsNothing);
  });

  testWidgets('有歌词：渲染 LyricView，不显示占位', (tester) async {
    final controller = LyricController()
      ..loadLyric('[00:01.00]第一行\n[00:05.00]第二行');
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
}
