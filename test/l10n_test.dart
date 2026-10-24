import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/utils/app_locale.dart';
import 'package:txvziwm/features/settings/settings_page.dart';
import 'package:txvziwm/features/shell/shell_controller.dart';
import 'package:txvziwm/features/shell/shell_l10n.dart';
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
      expect(find.text('Follow system'), findsOneWidget);
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
}
