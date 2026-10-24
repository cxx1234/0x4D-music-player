// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'App display language';

  @override
  String get settingsLanguageSystem => 'Follow system';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSimplifiedChinese => '简体中文';
}
