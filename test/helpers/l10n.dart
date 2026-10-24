import 'package:flutter/material.dart';
import 'package:txvziwm/l10n/app_localizations.dart';

/// 带本地化代理的 MaterialApp，供 widget 测试使用。
///
/// 默认 locale 为中文：既有测试断言的是中文文案；需要验证英文时显式传
/// `Locale('en')`。裸 `MaterialApp` 没有 `AppLocalizations`，
/// `context.l10n` 会抛错。
Widget localizedApp({
  required Widget home,
  Locale locale = const Locale('zh'),
  ThemeData? theme,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: theme,
    home: home,
  );
}

/// 纯 Dart 测试里直接取一份本地化文案（不依赖 BuildContext）。
Future<AppLocalizations> loadL10n([Locale locale = const Locale('zh')]) =>
    AppLocalizations.delegate.load(locale);
