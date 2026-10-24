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

  /// Separator used when joining a list of status fragments.
  ///
  /// In en, this message translates to:
  /// **', '**
  String get commonListSeparator;

  /// Library page title and sidebar label.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get libraryTitle;

  /// Empty/loading state title in the library.
  ///
  /// In en, this message translates to:
  /// **'Your library'**
  String get libraryYourLibrary;

  /// Hint shown when the library has no music folder.
  ///
  /// In en, this message translates to:
  /// **'Import a music folder to get started'**
  String get libraryEmptyHint;

  /// Button that opens the music folder picker.
  ///
  /// In en, this message translates to:
  /// **'Import folder'**
  String get libraryImportFolder;

  /// Banner shown when a sandbox bookmark can no longer be restored.
  ///
  /// In en, this message translates to:
  /// **'Music folder access has expired. Grant access again.'**
  String get libraryAccessExpired;

  /// Banner action that asks for folder access again.
  ///
  /// In en, this message translates to:
  /// **'Grant access again'**
  String get libraryRegrant;

  /// Placeholder in the library search field.
  ///
  /// In en, this message translates to:
  /// **'Search songs'**
  String get librarySearchSongsHint;

  /// Tooltip for the library sort menu.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get librarySort;

  /// Button that rescans the whole library.
  ///
  /// In en, this message translates to:
  /// **'Rescan'**
  String get libraryRescan;

  /// Scan progress phase: collecting files.
  ///
  /// In en, this message translates to:
  /// **'Scanning folders…'**
  String get libraryScanningFolders;

  /// Scan progress phase without further detail.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get libraryProcessing;

  /// Tooltip for rescanning a single music folder.
  ///
  /// In en, this message translates to:
  /// **'Rescan this folder'**
  String get libraryRescanFolder;

  /// Tooltip for removing a music folder.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get libraryRemoveFolder;

  /// Scan summary when nothing was added or updated.
  ///
  /// In en, this message translates to:
  /// **'No new files'**
  String get libraryScanNoNew;

  /// Albums page title and sidebar label.
  ///
  /// In en, this message translates to:
  /// **'Albums'**
  String get albumTitle;

  /// Album subtitle when the album has no album artist.
  ///
  /// In en, this message translates to:
  /// **'Various artists'**
  String get albumVariousArtists;

  /// Placeholder in the album search field.
  ///
  /// In en, this message translates to:
  /// **'Search albums'**
  String get albumSearchHint;

  /// Albums page empty state title.
  ///
  /// In en, this message translates to:
  /// **'No albums yet'**
  String get albumEmptyTitle;

  /// Albums page empty state hint.
  ///
  /// In en, this message translates to:
  /// **'Albums are grouped automatically after you import a music folder'**
  String get albumEmptyHint;

  /// Album context menu action.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get albumAddToQueue;

  /// SnackBar shown when an album has no playable songs.
  ///
  /// In en, this message translates to:
  /// **'This album has no playable songs'**
  String get albumNoPlayable;

  /// Artists page title and sidebar label.
  ///
  /// In en, this message translates to:
  /// **'Artists'**
  String get artistTitle;

  /// Placeholder in the artist search field.
  ///
  /// In en, this message translates to:
  /// **'Search artists'**
  String get artistSearchHint;

  /// Artists page empty state title.
  ///
  /// In en, this message translates to:
  /// **'No artists yet'**
  String get artistEmptyTitle;

  /// Artists page empty state hint.
  ///
  /// In en, this message translates to:
  /// **'Artists are grouped automatically after you import a music folder'**
  String get artistEmptyHint;

  /// SnackBar shown when an artist has no playable songs.
  ///
  /// In en, this message translates to:
  /// **'This artist has no playable songs'**
  String get artistNoPlayable;

  /// Song sort order: title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get sortTitle;

  /// Song sort order: date added.
  ///
  /// In en, this message translates to:
  /// **'Recently added'**
  String get sortDateAdded;

  /// Song sort order: play count.
  ///
  /// In en, this message translates to:
  /// **'Most played'**
  String get sortPlayCount;

  /// Song sort order: year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get sortYear;

  /// Subtitle with the number of songs in the library.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String librarySongCount(int count);

  /// Subtitle with the number of matching songs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{Matched 1 song} other{Matched {count} songs}}'**
  String librarySongMatch(int count);

  /// Scan summary: added songs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Added 1 song} other{Added {count} songs}}'**
  String libraryScanAdded(int count);

  /// Scan summary: updated songs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Updated 1 song} other{Updated {count} songs}}'**
  String libraryScanUpdated(int count);

  /// Scan summary: songs marked missing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song removed} other{{count} songs removed}}'**
  String libraryScanRemoved(int count);

  /// Scan summary: purged ghost rows.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Cleared 1 leftover row} other{Cleared {count} leftover rows}}'**
  String libraryScanPurged(int count);

  /// Scan summary: failed files.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 failure} other{{count} failures}}'**
  String libraryScanErrors(int count);

  /// Subtitle with the number of albums.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No albums} =1{1 album} other{{count} albums}}'**
  String albumCount(int count);

  /// Subtitle with the number of matching albums.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{Matched 1 album} other{Matched {count} albums}}'**
  String albumMatch(int count);

  /// Album detail info with the number of songs.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String albumSongCount(int count);

  /// Subtitle with the number of artists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No artists} =1{1 artist} other{{count} artists}}'**
  String artistCount(int count);

  /// Subtitle with the number of matching artists.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{Matched 1 artist} other{Matched {count} artists}}'**
  String artistMatch(int count);

  /// Artist row subtitle: song count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 song} other{{count} songs}}'**
  String artistSongs(int count);

  /// Artist row subtitle: album count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 album} other{{count} albums}}'**
  String artistAlbums(int count);

  /// Artist detail section header for albums.
  ///
  /// In en, this message translates to:
  /// **'Albums ({count})'**
  String artistSectionAlbums(int count);

  /// Artist detail section header for songs.
  ///
  /// In en, this message translates to:
  /// **'Songs ({count})'**
  String artistSectionSongs(int count);

  /// Scan progress phase with processed and total counts.
  ///
  /// In en, this message translates to:
  /// **'Parsing metadata {processed}/{total}…'**
  String libraryParsingMetadata(int processed, int total);

  /// Banner prefix for a finished scan.
  ///
  /// In en, this message translates to:
  /// **'Scan complete: {summary}'**
  String libraryScanDone(String summary);

  /// SnackBar shown when a scan throws.
  ///
  /// In en, this message translates to:
  /// **'Scan failed: {error}'**
  String libraryScanFailed(String error);

  /// Generic save action.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic delete action.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Generic create action.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// Label for a playlist name field.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// Playlists page title and sidebar label.
  ///
  /// In en, this message translates to:
  /// **'Playlists'**
  String get playlistTitle;

  /// Placeholder in the playlist search field.
  ///
  /// In en, this message translates to:
  /// **'Search playlists'**
  String get playlistSearchHint;

  /// Dialog title and action for creating a playlist.
  ///
  /// In en, this message translates to:
  /// **'New playlist'**
  String get playlistNew;

  /// Hint for the playlist name field.
  ///
  /// In en, this message translates to:
  /// **'For example: My favorites'**
  String get playlistCreateHint;

  /// Menu item and file picker title for M3U import.
  ///
  /// In en, this message translates to:
  /// **'Import playlist'**
  String get playlistImport;

  /// SnackBar when an M3U file cannot be read.
  ///
  /// In en, this message translates to:
  /// **'Import failed: couldn\'t read the file'**
  String get playlistImportReadFailed;

  /// SnackBar when an imported M3U matched no library songs.
  ///
  /// In en, this message translates to:
  /// **'No songs matched. Make sure the playlist\'s files are in your library.'**
  String get playlistImportNoMatches;

  /// SnackBar when the export menu runs without playlists.
  ///
  /// In en, this message translates to:
  /// **'No playlists to export'**
  String get playlistExportEmpty;

  /// Bottom sheet title for choosing an export target.
  ///
  /// In en, this message translates to:
  /// **'Choose a playlist to export'**
  String get playlistChooseExport;

  /// SnackBar when building an M3U failed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: couldn\'t build the playlist content'**
  String get playlistExportFailed;

  /// File picker title for M3U export.
  ///
  /// In en, this message translates to:
  /// **'Export playlist'**
  String get playlistExport;

  /// Dialog title for renaming a playlist.
  ///
  /// In en, this message translates to:
  /// **'Rename playlist'**
  String get playlistRename;

  /// Dialog title for deleting a playlist.
  ///
  /// In en, this message translates to:
  /// **'Delete playlist'**
  String get playlistDelete;

  /// Playlist detail empty state title.
  ///
  /// In en, this message translates to:
  /// **'This playlist is empty'**
  String get playlistEmpty;

  /// Playlist detail empty state hint.
  ///
  /// In en, this message translates to:
  /// **'Use the \"Add songs\" button in the top-right corner to add songs'**
  String get playlistEmptyHint;

  /// Section header above user-created playlists.
  ///
  /// In en, this message translates to:
  /// **'My playlists'**
  String get playlistMyPlaylists;

  /// Favorites page title and card label.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get playlistFavorites;

  /// Playlists page empty state title.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet'**
  String get playlistListEmpty;

  /// Playlists page empty state hint.
  ///
  /// In en, this message translates to:
  /// **'Tap + in the top-right corner to create a playlist'**
  String get playlistListEmptyHint;

  /// Import target sheet section header.
  ///
  /// In en, this message translates to:
  /// **'Add to an existing playlist'**
  String get playlistImportIntoExisting;

  /// Favorites empty state title.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get playlistFavoritesEmpty;

  /// Favorites empty state hint.
  ///
  /// In en, this message translates to:
  /// **'Use \"Like\" in a song\'s \"More\" menu to add it'**
  String get playlistFavoritesEmptyHint;

  /// Tooltip for adding songs to a playlist.
  ///
  /// In en, this message translates to:
  /// **'Add songs'**
  String get playlistAddSongs;

  /// Tooltip that enables drag-to-reorder.
  ///
  /// In en, this message translates to:
  /// **'Manual sort'**
  String get playlistManualSort;

  /// Tooltip that leaves drag-to-reorder mode.
  ///
  /// In en, this message translates to:
  /// **'Done sorting'**
  String get playlistDoneSorting;

  /// Playlist menu item that exports an M3U file.
  ///
  /// In en, this message translates to:
  /// **'Export as M3U…'**
  String get playlistExportM3u;

  /// Playlist menu item that sorts by song title.
  ///
  /// In en, this message translates to:
  /// **'Sort by name'**
  String get playlistSortByName;

  /// Playlist card menu item: export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get playlistMenuExport;

  /// Playlist card menu item: rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get playlistMenuRename;

  /// Song menu item in a playlist detail page.
  ///
  /// In en, this message translates to:
  /// **'Remove from playlist'**
  String get playlistRemoveFrom;

  /// Song menu item that opens the playlist picker.
  ///
  /// In en, this message translates to:
  /// **'Add to playlist'**
  String get playlistAddTo;

  /// Playlist picker empty state.
  ///
  /// In en, this message translates to:
  /// **'No playlists yet. Create one first.'**
  String get playlistPickerEmpty;

  /// Playlist picker entry that creates a playlist.
  ///
  /// In en, this message translates to:
  /// **'New playlist…'**
  String get playlistNewEllipsis;

  /// Add-songs sheet empty search result.
  ///
  /// In en, this message translates to:
  /// **'No matching songs'**
  String get playlistNoMatchingSongs;

  /// Add-songs sheet button when nothing is selected.
  ///
  /// In en, this message translates to:
  /// **'Select songs'**
  String get playlistSelectSongs;

  /// Song menu item: append to the playback queue.
  ///
  /// In en, this message translates to:
  /// **'Add to queue'**
  String get songAddToQueue;

  /// Song menu item: play after the current track.
  ///
  /// In en, this message translates to:
  /// **'Play next'**
  String get songPlayNext;

  /// SnackBar when an empty queue starts playing.
  ///
  /// In en, this message translates to:
  /// **'Started playing'**
  String get songStartedPlaying;

  /// SnackBar after adding a song to play next.
  ///
  /// In en, this message translates to:
  /// **'Added to play next'**
  String get songAddedNext;

  /// SnackBar after appending a song to the queue.
  ///
  /// In en, this message translates to:
  /// **'Added to the queue'**
  String get songAddedQueue;

  /// Playlists page subtitle count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No playlists} =1{1 playlist} other{{count} playlists}}'**
  String playlistCount(int count);

  /// Playlists page subtitle while searching.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No matches} =1{Matched 1 playlist} other{Matched {count} playlists}}'**
  String playlistMatch(int count);

  /// SnackBar after importing songs into a playlist.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Imported 1 song into \"{name}\"} other{Imported {count} songs into \"{name}\"}}'**
  String playlistImported(int count, String name);

  /// Import target sheet: entries not found in the library.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unmatched (not in your library)} other{{count} unmatched (not in your library)}}'**
  String playlistImportUnmatched(int count);

  /// Import target sheet title.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Import 1 song} other{Import {count} songs}}'**
  String playlistImportSheetTitle(int count);

  /// SnackBar after exporting a playlist.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Exported 1 song} other{Exported {count} songs}}'**
  String playlistExported(int count);

  /// Add-songs sheet confirm button.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Select songs} =1{Add (1)} other{Add ({count})}}'**
  String playlistAddSelected(int count);

  /// Fallback name when a playlist id cannot be resolved.
  ///
  /// In en, this message translates to:
  /// **'Playlist'**
  String get playlistFallbackName;

  /// Import SnackBar: entries that did not match a library song.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 unmatched} other{{count} unmatched}}'**
  String playlistSkippedCount(int count);

  /// Import target sheet: create a playlist named after the M3U file.
  ///
  /// In en, this message translates to:
  /// **'New playlist \"{name}\"'**
  String playlistCreateNamed(String name);

  /// Confirmation body for deleting a playlist.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This can\'t be undone.'**
  String playlistDeleteConfirm(String name);

  /// Generic close action or tooltip.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Tooltip for collapsing the now-playing page.
  ///
  /// In en, this message translates to:
  /// **'Collapse'**
  String get playerCollapse;

  /// Title of the now-playing page.
  ///
  /// In en, this message translates to:
  /// **'Now playing'**
  String get playerNowPlaying;

  /// Now-playing tab: lyrics.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get playerLyricsTab;

  /// Now-playing tab: playback queue.
  ///
  /// In en, this message translates to:
  /// **'Queue'**
  String get playerQueueTab;

  /// Empty now-playing page hint.
  ///
  /// In en, this message translates to:
  /// **'Pick a song to start playing'**
  String get playerPickSongToStart;

  /// Toolbar label above the lyrics view.
  ///
  /// In en, this message translates to:
  /// **'Lyrics'**
  String get lyricsTitle;

  /// Tooltip for the lyric text-size menu.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get lyricsTextSizeTooltip;

  /// Tooltip that opens the lyrics settings page.
  ///
  /// In en, this message translates to:
  /// **'Lyrics display settings'**
  String get lyricsSettingsTooltip;

  /// Tooltip when the translation subline is visible.
  ///
  /// In en, this message translates to:
  /// **'Hide translation'**
  String get lyricsHideTranslation;

  /// Tooltip when the translation subline is hidden.
  ///
  /// In en, this message translates to:
  /// **'Show translation'**
  String get lyricsShowTranslation;

  /// Empty lyrics placeholder.
  ///
  /// In en, this message translates to:
  /// **'No lyrics'**
  String get lyricsEmpty;

  /// Queue footer: sequential playback.
  ///
  /// In en, this message translates to:
  /// **'Sequential'**
  String get queueSequential;

  /// Queue footer: shuffled playback.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get queueShuffle;

  /// Queue footer: repeat the whole list.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get queueRepeatAll;

  /// Queue footer: repeat the current track.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get queueRepeatOne;

  /// Suffix appended to the queue footer when scrolled to the bottom.
  ///
  /// In en, this message translates to:
  /// **' · End of queue'**
  String get queueAtBottomSuffix;

  /// Dialog title that clears the queue.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get queueClearTitle;

  /// Confirmation body for clearing the queue.
  ///
  /// In en, this message translates to:
  /// **'Clear the current queue?'**
  String get queueClearConfirm;

  /// Tooltip for the clear-queue button.
  ///
  /// In en, this message translates to:
  /// **'Clear queue'**
  String get queueClearTooltip;

  /// Queue row context menu item.
  ///
  /// In en, this message translates to:
  /// **'Remove from queue'**
  String get queueRemove;

  /// Empty queue placeholder.
  ///
  /// In en, this message translates to:
  /// **'The queue is empty'**
  String get queueEmpty;

  /// Tooltip for scrolling the queue to the current track.
  ///
  /// In en, this message translates to:
  /// **'Go to now playing'**
  String get queueLocate;

  /// Tooltip for deleting selected queue rows.
  ///
  /// In en, this message translates to:
  /// **'Delete selected ({count})'**
  String queueDeleteSelected(int count);

  /// Tooltip that enters multi-select delete mode.
  ///
  /// In en, this message translates to:
  /// **'Select to delete'**
  String get queueSelectDelete;

  /// Tooltip for the single-repeat toggle.
  ///
  /// In en, this message translates to:
  /// **'Repeat one'**
  String get queueSingleRepeat;

  /// Play-mode tooltip: repeat the list.
  ///
  /// In en, this message translates to:
  /// **'Repeat all'**
  String get queueModeRepeatAll;

  /// Sleep timer button label and HUD prefix.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer'**
  String get sleepTimerTitle;

  /// Sleep timer button label while fading out.
  ///
  /// In en, this message translates to:
  /// **'Fading out'**
  String get sleepTimerFading;

  /// Sleep timer mode: stop after the current track.
  ///
  /// In en, this message translates to:
  /// **'End of track'**
  String get sleepTimerEndOfTrack;

  /// Sleep timer mode: stop at the end of the queue.
  ///
  /// In en, this message translates to:
  /// **'End of playlist'**
  String get sleepTimerEndOfQueue;

  /// Sleep timer label while the fade-out is running.
  ///
  /// In en, this message translates to:
  /// **'Fading out…'**
  String get sleepTimerFadingLabel;

  /// HUD text after playback starts.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get feedbackPlaying;

  /// HUD text after playback pauses.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get feedbackPaused;

  /// HUD text when Previous is pressed at the start of the queue.
  ///
  /// In en, this message translates to:
  /// **'Already at the first track'**
  String get feedbackFirstTrack;

  /// HUD text when Next is pressed at the end of the queue.
  ///
  /// In en, this message translates to:
  /// **'Already at the last track'**
  String get feedbackLastTrack;

  /// HUD text after stopping playback without clearing the queue.
  ///
  /// In en, this message translates to:
  /// **'Stopped · queue kept'**
  String get feedbackStopped;

  /// HUD text after cancelling the sleep timer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer cancelled'**
  String get feedbackSleepTimerCancelled;

  /// HUD text when a playback action has no current track.
  ///
  /// In en, this message translates to:
  /// **'Nothing is playing'**
  String get feedbackNoTrack;

  /// SnackBar when a file fails without a known title.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play this file; skipped to the next track'**
  String get playbackFailedNoTitle;

  /// Notice when the timer expires and the app waits for the track to end.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer reached; waiting for the current track to finish'**
  String get sleepTimerExpiredWaiting;

  /// Notice after the sleep timer fades out and pauses.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer finished; playback paused'**
  String get sleepTimerFinishedPaused;

  /// Notice after the sleep timer stops at a track boundary.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer finished; playback stopped'**
  String get sleepTimerFinishedStopped;

  /// Queue toolbar count.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No songs} =1{1 song} other{{count} songs}}'**
  String queueTotalCount(int count);

  /// Sleep timer preset label and HUD.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute} other{{count} minutes}}'**
  String sleepTimerMinutes(int count);

  /// SnackBar when consecutive playback failures stop auto-skip.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play {count} tracks in a row; auto-skip stopped'**
  String playbackFailedRepeated(int count);

  /// Tooltip for the play-mode button.
  ///
  /// In en, this message translates to:
  /// **'Play mode: {mode}'**
  String queuePlayModeTooltip(String mode);

  /// Sleep timer menu item that cancels an active timer.
  ///
  /// In en, this message translates to:
  /// **'Cancel timer ({state})'**
  String sleepTimerCancel(String state);

  /// Tooltip for an active sleep timer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer · {state}'**
  String sleepTimerActiveTooltip(String state);

  /// HUD message when starting a sleep timer.
  ///
  /// In en, this message translates to:
  /// **'Sleep timer · {state}'**
  String feedbackSleepTimerHud(String state);

  /// SnackBar when a titled file fails and playback skips ahead.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play {title}; skipped to the next track'**
  String playbackFailedWithTitle(String title);
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
