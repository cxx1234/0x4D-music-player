import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/models/lyric_text_size.dart';
import 'package:txvziwm/features/settings/lyrics_settings_page.dart';
import 'package:txvziwm/features/settings/settings_page.dart';

import 'helpers/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('外观 › 歌词显示：点击后打开歌词设置页', (tester) async {
    await tester.pumpWidget(
      localizedApp(home: const Scaffold(body: SettingsPage())),
    );

    final row = find.text('歌词显示');
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    // 页面里的循环预览会持续排帧，不能用 pumpAndSettle。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LyricsSettingsPage), findsOneWidget);
    expect(find.text('字号'), findsOneWidget);
    expect(find.text('翻译副行'), findsOneWidget);
  });

  testWidgets('ServiceLocator 未就绪时歌词页仍可独立构建', (tester) async {
    await tester.pumpWidget(localizedApp(home: const LyricsSettingsPage()));

    expect(find.text('字号'), findsOneWidget);
    expect(find.text('翻译副行'), findsOneWidget);

    await tester.tap(find.text('大'));
    await tester.pump();

    final button = tester.widget<SegmentedButton<LyricTextSize>>(
      find.byType(SegmentedButton<LyricTextSize>),
    );
    expect(button.selected, {LyricTextSize.large});
  });
}
