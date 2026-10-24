import 'package:flutter/widgets.dart';

import '../core/utils/app_locale.dart';
import 'app_localizations.dart';

/// 按持久化语言名同步取一份 [AppLocalizations]。
///
/// 供没有 `BuildContext` 的服务（HUD / 通知等）在**事件发生时**取当前文案。
/// 解析规则与 `MaterialApp` 保持一致：显式 en/zh 优先，`system` 跟随平台，
/// 非中文回退英文（见 `docs/I18n.md`）。
AppLocalizations appLocalizationsFor(
  String localeName, {
  Locale? platformLocale,
}) {
  final override = appLocaleFromName(localeName);
  final locale =
      override ??
      platformLocale ??
      WidgetsBinding.instance.platformDispatcher.locale;
  return lookupAppLocalizations(
    locale.languageCode.toLowerCase() == 'zh'
        ? const Locale('zh')
        : const Locale('en'),
  );
}
