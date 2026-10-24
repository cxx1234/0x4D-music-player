import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/song_sort_order.dart';
import 'package:txvziwm/core/models/accent_color.dart';
import 'package:txvziwm/core/models/lyric_line_transition_style.dart';
import 'package:txvziwm/core/utils/app_locale.dart';
import 'package:txvziwm/features/settings/lyrics_settings_page.dart';
import 'package:txvziwm/features/settings/settings_page.dart';
import 'package:txvziwm/features/shell/shell_controller.dart';
import 'package:txvziwm/features/shell/shell_l10n.dart';
import 'package:txvziwm/l10n/app_l10n.dart';
import 'package:txvziwm/l10n/enum_labels.dart';
import 'package:txvziwm/widgets/search_empty_state.dart';

import 'helpers/l10n.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('app locale helpers', () {
    test('appLocaleFromName 只映射受支持的语言，system 返回 null', () {
      expect(appLocaleFromName('system'), isNull);
      expect(appLocaleFromName('en'), const Locale('en'));
      expect(appLocaleFromName('zh'), const Locale('zh'));
      expect(appLocaleFromName('ja'), isNull);
    });

    test('normalizeAppLocaleName 丢弃未知值', () {
      expect(normalizeAppLocaleName('en'), 'en');
      expect(normalizeAppLocaleName('zh'), 'zh');
      expect(normalizeAppLocaleName('ja'), 'system');
      expect(normalizeAppLocaleName(null), 'system');
    });

    test('显式语言优先于平台 locale', () {
      const platformZh = Locale('zh', 'CN');
      const platformEn = Locale('en', 'US');
      expect(isChineseUiLocale('en', platformLocale: platformZh), isFalse);
      expect(isChineseUiLocale('zh', platformLocale: platformEn), isTrue);
    });

    test('system：跟随平台 locale，非中文按英文处理', () {
      expect(
        isChineseUiLocale('system', platformLocale: const Locale('zh', 'CN')),
        isTrue,
      );
      expect(
        isChineseUiLocale('system', platformLocale: const Locale('en', 'US')),
        isFalse,
      );
      expect(
        isChineseUiLocale('system', platformLocale: const Locale('ja', 'JP')),
        isFalse,
      );
    });
  });

  group('AppLocalizations', () {
    test('中英文都提供语言设置文案', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));
      expect(en.settingsLanguageTitle, 'Language');
      expect(en.settingsLanguageSystem, 'Follow system');
      expect(zh.settingsLanguageTitle, '语言');
      expect(zh.settingsLanguageSystem, '跟随系统');
    });

    test('公共层文案：导航 / 启动错误 / 搜索占位', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));

      expect(NavigationItem.library.label(en), 'Library');
      expect(NavigationItem.playlists.label(en), 'Playlists');
      expect(NavigationItem.settings.label(zh), '设置');
      expect(en.startupFailedTitle, "Couldn't start the app");
      expect(en.playerPlayAll, 'Play all');
      expect(en.searchEmptyQuery('jazz'), 'No results for "jazz"');
      expect(zh.searchEmptyQuery('爵士'), '没有找到与「爵士」相关的内容');
    });

    testWidgets('SearchEmptyState 的占位文案跟随 locale', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          home: const Scaffold(body: SearchEmptyState(query: 'jazz')),
        ),
      );

      expect(find.text('No results for "jazz"'), findsOneWidget);
      expect(find.text('Try another keyword'), findsOneWidget);
    });

    testWidgets('设置页按 locale 展示语言行', (tester) async {
      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          home: const Scaffold(body: SettingsPage()),
        ),
      );

      // 「通用」分组在列表底部，测试视口内先滚到语言行。
      await tester.scrollUntilVisible(find.text('Language'), 300);
      expect(find.text('Language'), findsOneWidget);
      // 「Follow system」在主题模式里也有，限定在语言这一行内断言。
      final languageTile = find.ancestor(
        of: find.text('Language'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: languageTile, matching: find.text('Follow system')),
        findsOneWidget,
      );
    });

    testWidgets('中文 locale 展示原有中文文案', (tester) async {
      await tester.pumpWidget(
        localizedApp(home: const Scaffold(body: SettingsPage())),
      );

      await tester.scrollUntilVisible(find.text('语言'), 300);
      expect(find.text('语言'), findsOneWidget);
      // 「跟随系统」在主题模式里也有，限定在语言这一行内断言。
      final languageTile = find.ancestor(
        of: find.text('语言'),
        matching: find.byType(ListTile),
      );
      expect(
        find.descendant(of: languageTile, matching: find.text('跟随系统')),
        findsOneWidget,
      );
    });
  });

  group('设置域', () {
    test('枚举标签跟随 locale', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));

      expect(AccentColor.graphite.label(en), 'Graphite');
      expect(AccentColor.graphite.label(zh), '石墨灰');
      expect(LyricLineTransitionStyle.slide.description(zh), '从下方滑入并淡入');
      expect(
        LyricLineTransitionStyle.slide.description(en),
        'Slides up and fades in',
      );
    });

    test('设置页文案中英对应', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));

      expect(en.settingsTitle, 'Settings');
      expect(zh.settingsTitle, '设置');
      expect(en.settingsSectionPlayback, 'Playback');
      expect(zh.settingsSectionPlayback, '播放设置');
      expect(en.lyricsTextSizeTitle, 'Text size');
      expect(zh.lyricsTextSizeTitle, '字号');
      expect(en.aboutTagline, 'Local music player');
      expect(zh.aboutTagline, '本地音乐播放器');
    });

    test('清理缓存结果按数量走复数', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));

      expect(en.settingsCoverCacheCleared(0), 'No unused covers to clear');
      expect(en.settingsCoverCacheCleared(1), 'Removed 1 unused cover');
      expect(en.settingsCoverCacheCleared(3), 'Removed 3 unused covers');
      expect(zh.settingsCoverCacheCleared(3), '已清理 3 个未使用的封面');
    });

    testWidgets('英文设置页在宽布局下不溢出', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          home: const Scaffold(body: SettingsPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('英文歌词设置页在宽布局下不溢出', (tester) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        localizedApp(
          locale: const Locale('en'),
          home: const LyricsSettingsPage(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Text size'), findsOneWidget);
    });
  });

  group('音乐库 / 专辑 / 歌手', () {
    test('排序与计数文案跟随 locale', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));

      expect(SongSortOrder.dateAdded.label(en), 'Recently added');
      expect(SongSortOrder.dateAdded.label(zh), '最近添加');
      expect(en.librarySongCount(1), '1 song');
      expect(en.librarySongCount(120), '120 songs');
      expect(zh.librarySongCount(120), '120 首');
      expect(en.artistSongs(2), '2 songs');
      expect(zh.artistSongs(2), '2 首歌曲');
      expect(en.artistAlbums(1), '1 album');
      expect(en.albumMatch(0), 'No matches');
    });
  });

  group('服务层语言选择', () {
    test('appLocalizationsFor 跟随持久化语言，system 跟随平台', () {
      expect(
        appLocalizationsFor(
          'en',
          platformLocale: const Locale('zh'),
        ).settingsTitle,
        'Settings',
      );
      expect(
        appLocalizationsFor(
          'zh',
          platformLocale: const Locale('en'),
        ).settingsTitle,
        '设置',
      );
      expect(
        appLocalizationsFor(
          'system',
          platformLocale: const Locale('zh'),
        ).settingsTitle,
        '设置',
      );
      expect(
        appLocalizationsFor(
          'system',
          platformLocale: const Locale('en'),
        ).settingsTitle,
        'Settings',
      );
    });
  });

  group('播放页与播放反馈', () {
    test('播放页 / 歌词 / HUD / 错误文案', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));

      expect(en.playerNowPlaying, 'Now playing');
      expect(zh.playerQueueTab, '播放列表');
      expect(en.lyricsEmpty, 'No lyrics');
      expect(en.feedbackPlaying, 'Playing');
      expect(zh.feedbackFirstTrack, '已是第一首');
      expect(
        en.playbackFailedWithTitle('X'),
        "Couldn't play X; skipped to the next track",
      );
      expect(zh.playbackFailedRepeated(3), '连续 3 次无法播放，已停止自动跳转');
      expect(en.sleepTimerMinutes(5), '5 minutes');
      expect(zh.sleepTimerMinutes(5), '5 分钟');
      expect(en.sleepTimerCancel('5 minutes'), 'Cancel timer (5 minutes)');
    });
  });

  group('播放列表', () {
    test('导入/导出与选择按钮的复数', () async {
      final en = await loadL10n(const Locale('en'));
      final zh = await loadL10n(const Locale('zh'));

      expect(en.playlistImported(1, 'Mix'), 'Imported 1 song into "Mix"');
      expect(en.playlistImported(3, 'Mix'), 'Imported 3 songs into "Mix"');
      expect(zh.playlistImported(3, 'Mix'), '已导入 3 首到"Mix"');
      expect(en.playlistExported(1), 'Exported 1 song');
      expect(en.playlistAddSelected(0), 'Select songs');
      expect(en.playlistAddSelected(1), 'Add (1)');
      expect(zh.playlistAddSelected(3), '添加 (3)');
      expect(
        en.playlistDeleteConfirm('Mix'),
        'Delete "Mix"? This can\'t be undone.',
      );
    });
  });
}
