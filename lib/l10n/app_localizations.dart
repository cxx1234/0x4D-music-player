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

  /// Option that follows the operating system setting.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get commonFollowSystem;

  /// Generic cancel action.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Accent color preset: graphite.
  ///
  /// In en, this message translates to:
  /// **'Graphite'**
  String get accentGraphite;

  /// Accent color preset: deep purple.
  ///
  /// In en, this message translates to:
  /// **'Deep purple'**
  String get accentDeepPurple;

  /// Accent color preset: indigo.
  ///
  /// In en, this message translates to:
  /// **'Indigo'**
  String get accentIndigo;

  /// Accent color preset: blue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get accentBlue;

  /// Accent color preset: cyan.
  ///
  /// In en, this message translates to:
  /// **'Cyan'**
  String get accentCyan;

  /// Accent color preset: green.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get accentGreen;

  /// Accent color preset: orange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get accentOrange;

  /// Accent color preset: red.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get accentRed;

  /// Accent color preset: pink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get accentPink;

  /// Accent color preset: blue grey.
  ///
  /// In en, this message translates to:
  /// **'Blue grey'**
  String get accentBlueGrey;

  /// Lyric text size: small.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get lyricTextSizeSmall;

  /// Lyric text size: medium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get lyricTextSizeMedium;

  /// Lyric text size: large.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get lyricTextSizeLarge;

  /// Word-pop strength: default.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get lyricEffectStandard;

  /// Word-pop strength: strong.
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get lyricEffectStrong;

  /// Line transition: classic.
  ///
  /// In en, this message translates to:
  /// **'Classic'**
  String get lyricTransitionClassic;

  /// Description of the classic line transition.
  ///
  /// In en, this message translates to:
  /// **'Default size transition'**
  String get lyricTransitionClassicDescription;

  /// Line transition: scale.
  ///
  /// In en, this message translates to:
  /// **'Scale'**
  String get lyricTransitionScale;

  /// Description of the scale line transition.
  ///
  /// In en, this message translates to:
  /// **'Zooms in, then settles'**
  String get lyricTransitionScaleDescription;

  /// Line transition: slide.
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get lyricTransitionSlide;

  /// Description of the slide line transition.
  ///
  /// In en, this message translates to:
  /// **'Slides up and fades in'**
  String get lyricTransitionSlideDescription;

  /// Line transition: none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get lyricTransitionNone;

  /// Description of the none line transition.
  ///
  /// In en, this message translates to:
  /// **'Switches instantly'**
  String get lyricTransitionNoneDescription;

  /// Slide alignment: left.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get lyricAlignmentLeft;

  /// Slide alignment: right.
  ///
  /// In en, this message translates to:
  /// **'Right'**
  String get lyricAlignmentRight;

  /// Distance blur: off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get lyricBlurOff;

  /// Distance blur: light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lyricBlurLight;

  /// Distance blur: standard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get lyricBlurStandard;

  /// Theme mode: light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// Theme mode: dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// Settings page title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Settings section: library.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get settingsSectionLibrary;

  /// Settings section: playback.
  ///
  /// In en, this message translates to:
  /// **'Playback'**
  String get settingsSectionPlayback;

  /// Settings section: appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsSectionAppearance;

  /// Settings section: general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsSectionGeneral;

  /// Title of the dialog that clears the cover cache.
  ///
  /// In en, this message translates to:
  /// **'Clear cover cache'**
  String get settingsClearCoverCacheTitle;

  /// Body of the clear-cover-cache dialog.
  ///
  /// In en, this message translates to:
  /// **'Deletes cover files that are no longer used by any song or album.\nCovers in use are unaffected.'**
  String get settingsClearCoverCacheBody;

  /// Confirm button for clearing the cover cache.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearCoverCacheAction;

  /// SnackBar shown when notification permission was denied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off, so track-change banners won\'t appear'**
  String get settingsNotificationsDenied;

  /// SnackBar action that opens the system notification settings.
  ///
  /// In en, this message translates to:
  /// **'Open system settings'**
  String get settingsOpenSystemSettings;

  /// Settings row that re-parses the whole library.
  ///
  /// In en, this message translates to:
  /// **'Force rescan'**
  String get settingsForceRescanTitle;

  /// Subtitle when music folders exist.
  ///
  /// In en, this message translates to:
  /// **'Re-parses every song to fix broken metadata or covers'**
  String get settingsForceRescanSubtitle;

  /// Subtitle when no music folder has been added.
  ///
  /// In en, this message translates to:
  /// **'Add a music folder first'**
  String get settingsForceRescanNoFolders;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Resume last position'**
  String get settingsResumeTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Restores your previous playback position on launch'**
  String get settingsResumeSubtitle;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Show a system notification on track change'**
  String get settingsTrackNotificationTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Only appears in the background or when the window is closed'**
  String get settingsTrackNotificationSubtitle;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Finish the current track before sleeping'**
  String get settingsSleepFinishTrackTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'When off, playback fades out and pauses when the timer ends'**
  String get settingsSleepFinishTrackSubtitle;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Pick an accent color or follow the system'**
  String get settingsAccentSubtitle;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsThemeTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the app\'s light or dark appearance'**
  String get settingsThemeSubtitle;

  /// Settings row that opens the lyrics settings page.
  ///
  /// In en, this message translates to:
  /// **'Lyrics display'**
  String get settingsLyricsTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Text size, translation and lyric effects'**
  String get settingsLyricsSubtitle;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Progress fill in the player bar'**
  String get settingsNowPlayingFillTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'The bar background fills left to right while playing'**
  String get settingsNowPlayingFillSubtitle;

  /// Settings row that opens the log viewer.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get settingsLogsTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'View app runtime logs'**
  String get settingsLogsSubtitle;

  /// Settings row title.
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsCacheTitle;

  /// Settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Cover image cache (safe to clear)'**
  String get settingsCacheSubtitle;

  /// Settings row that opens the about page.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// Title of the lyrics settings page.
  ///
  /// In en, this message translates to:
  /// **'Lyrics display'**
  String get lyricsSettingsTitle;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get lyricsTextSizeTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Adjust lyric and translation text size'**
  String get lyricsTextSizeSubtitle;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Translation line'**
  String get lyricsTranslationTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows a translation under the original when available'**
  String get lyricsTranslationSubtitle;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Per-character fill'**
  String get lyricsWordFillTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Fills each sung character with the accent color'**
  String get lyricsWordFillSubtitle;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Word pop'**
  String get lyricsWordLiftTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Each sung character jumps up and stays raised for the line'**
  String get lyricsWordLiftSubtitle;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Effect strength'**
  String get lyricsEffectStrengthTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'How high each character jumps'**
  String get lyricsEffectStrengthSubtitle;

  /// Hint below the word-pop settings.
  ///
  /// In en, this message translates to:
  /// **'Plain LRC simulates per-character timing. QRC / YRC use the word timings stored in the file.'**
  String get lyricsWordTimingHint;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Line transition'**
  String get lyricsTransitionTitle;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Alignment'**
  String get lyricsAlignmentTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Slide direction follows the aligned edge'**
  String get lyricsAlignmentSubtitle;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Line wave'**
  String get lyricsLineWaveTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Lines shift and rise in sequence'**
  String get lyricsLineWaveSubtitle;

  /// Hint below the line-wave setting.
  ///
  /// In en, this message translates to:
  /// **'Applies to whole lines and stacks with word pop; turning on both can look busy.'**
  String get lyricsLineWaveHint;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Distance blur'**
  String get lyricsBlurTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Lines blur more the farther they are from the current one; stays sharp while browsing'**
  String get lyricsBlurSubtitle;

  /// Hint below the distance-blur setting.
  ///
  /// In en, this message translates to:
  /// **'Adds one off-screen blur layer per line. Turn it off on slower machines or when stacking many effects.'**
  String get lyricsBlurHint;

  /// Lyrics settings row title.
  ///
  /// In en, this message translates to:
  /// **'Countdown dots'**
  String get lyricsCountdownTitle;

  /// Lyrics settings row subtitle.
  ///
  /// In en, this message translates to:
  /// **'Shows three fading dots for intros and interludes'**
  String get lyricsCountdownSubtitle;

  /// Hint below the countdown setting.
  ///
  /// In en, this message translates to:
  /// **'Plain LRC needs a blank timestamp at the interlude (for example [00:12.00]) to show them.'**
  String get lyricsCountdownHint;

  /// Lyrics settings section: text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get lyricsSectionText;

  /// Lyrics settings section: text effects.
  ///
  /// In en, this message translates to:
  /// **'Text effects'**
  String get lyricsSectionEffects;

  /// Lyrics settings section: line motion.
  ///
  /// In en, this message translates to:
  /// **'Line motion'**
  String get lyricsSectionLineMotion;

  /// Label above the looped lyrics preview.
  ///
  /// In en, this message translates to:
  /// **'Loop preview'**
  String get lyricsPreviewLoop;

  /// About page title.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// About page tagline.
  ///
  /// In en, this message translates to:
  /// **'Local music player'**
  String get aboutTagline;

  /// About page row title.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get aboutLicenses;

  /// About page row title.
  ///
  /// In en, this message translates to:
  /// **'Project home'**
  String get aboutProjectHome;

  /// SnackBar shown after copying the project URL.
  ///
  /// In en, this message translates to:
  /// **'Project link copied'**
  String get aboutLinkCopied;

  /// Log viewer page title.
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logsTitle;

  /// Tooltip for the log date picker.
  ///
  /// In en, this message translates to:
  /// **'Select date'**
  String get logsSelectDate;

  /// Empty state in the log viewer.
  ///
  /// In en, this message translates to:
  /// **'No logs yet'**
  String get logsEmpty;

  /// Explains why the log viewer is empty in debug builds.
  ///
  /// In en, this message translates to:
  /// **'This is a debug build, so logs only go to the console and don\'t appear here. Release and profile builds write log files.'**
  String get logsDebugHint;

  /// Log detail page title.
  ///
  /// In en, this message translates to:
  /// **'Log details'**
  String get logDetailTitle;

  /// SnackBar after clearing the cover cache.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No unused covers to clear} =1{Removed 1 unused cover} other{Removed {count} unused covers}}'**
  String settingsCoverCacheCleared(int count);

  /// Settings row subtitle showing the app version.
  ///
  /// In en, this message translates to:
  /// **'Version {version} · Open-source licenses'**
  String settingsAboutSubtitle(String version);

  /// Version line on the about page.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// Lyrics settings section: countdown.
  ///
  /// In en, this message translates to:
  /// **'Countdown'**
  String get lyricsSectionCountdown;
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
