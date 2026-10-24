import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// `context.l10n.settingsLanguageTitle` 形式的取用入口。
extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
