import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// Settings row title for the app display language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// Settings row subtitle explaining that the setting changes the app UI language.
  ///
  /// In en, this message translates to:
  /// **'App display language'**
  String get settingsLanguageSubtitle;

  /// Language option: use the operating system language (English for non-Chinese systems).
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsLanguageSystem;

  /// Language option: English.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// Language option: Simplified Chinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageSimplifiedChinese;

  /// Tooltip for the back button on detail pages.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Tooltip for the button that clears the search field.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// Tooltip for the button that exits search mode.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get commonCloseSearch;

  /// Tooltip for the overflow menu button.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// Placeholder text in the search field when no specific hint is provided.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// Sidebar navigation label for the music library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get navLibrary;

  /// Sidebar navigation label for albums.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get navAlbums;

  /// Sidebar navigation label for artists.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get navArtists;

  /// Sidebar navigation label for playlists.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get navPlaylists;

  /// Sidebar navigation label for settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Title of the full-screen page shown when app services fail to initialize.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start the app'**
  String get startupFailedTitle;

  /// Body text on the startup error page.
  ///
  /// In en, this message translates to:
  /// **'App services couldn\'t be initialized. Try again. If this keeps happening, copy the error details and report them.'**
  String get startupFailedMessage;

  /// Button that retries app initialization.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get startupRetry;

  /// Button that copies the startup error to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy error details'**
  String get startupCopyDetails;

  /// Playback control tooltip for the previous track.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get playerPrevious;

  /// Playback control tooltip for starting playback.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// Playback control tooltip for pausing playback.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// Playback control tooltip for the next track.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get playerNext;

  /// Button that plays every song in the current collection.
  ///
  /// In en, this message translates to:
  /// **'Play all'**
  String get playerPlayAll;

  /// Button that adds the current song to favorites.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get playerLike;

  /// Button that removes the current song from favorites.
  ///
  /// In en, this message translates to:
  /// **'Unlike'**
  String get playerUnlike;

  /// Song title placeholder in the mini player when the queue is empty.
  ///
  /// In en, this message translates to:
  /// **'Nothing playing'**
  String get nowPlayingNotPlaying;

  /// Artist placeholder in the mini player when the queue is empty.
  ///
  /// In en, this message translates to:
  /// **'Pick a song'**
  String get nowPlayingPickSong;

  /// Empty state title when a search has no results and no query is available.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get searchEmptyTitle;

  /// Empty state title that includes the search query.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\"'**
  String searchEmptyQuery(String query);

  /// Hint shown below the empty search state.
  ///
  /// In en, this message translates to:
  /// **'Try another keyword'**
  String get searchEmptyHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
