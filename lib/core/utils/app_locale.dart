import 'package:flutter/widgets.dart';

/// 持久化的界面语言名。
///
/// `'system'` 表示跟随系统；实际支持的语言必须与 `AppLocalizations.supportedLocales`
/// 一致（当前为 `en` / `zh`）。未知值一律回退 `'system'`，避免旧配置或手改配置
/// 把界面锁在 MaterialApp 不支持的语言上。
const Set<String> kAppLocaleNames = {'system', 'en', 'zh'};

/// 把持久化值规范化为受支持的界面语言名。
String normalizeAppLocaleName(String? name) =>
    kAppLocaleNames.contains(name) ? name! : 'system';

/// 持久化名 → [MaterialApp.locale]；`'system'` 返回 null（交给系统解析）。
Locale? appLocaleFromName(String name) => switch (name) {
  'en' => const Locale('en'),
  'zh' => const Locale('zh'),
  _ => null,
};

/// 界面语言是否为中文。
///
/// 当前只用于歌词：中文界面才显示 `.lrc` 的中文翻译副行。`'system'` 时跟随平台
/// locale；非中文系统按 `supportedLocales` 的顺序回退英文（与 MaterialApp 一致）。
bool isChineseUiLocale(String name, {Locale? platformLocale}) {
  switch (name) {
    case 'zh':
      return true;
    case 'en':
      return false;
    default:
      final locale =
          platformLocale ?? WidgetsBinding.instance.platformDispatcher.locale;
      return locale.languageCode.toLowerCase() == 'zh';
  }
}
