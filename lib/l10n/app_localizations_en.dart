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

  @override
  String get commonBack => 'Back';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonCloseSearch => 'Close search';

  @override
  String get commonMore => 'More';

  @override
  String get commonSearch => 'Search';

  @override
  String get navLibrary => 'Library';

  @override
  String get navAlbums => 'Albums';

  @override
  String get navArtists => 'Artists';

  @override
  String get navPlaylists => 'Playlists';

  @override
  String get navSettings => 'Settings';

  @override
  String get startupFailedTitle => 'Couldn\'t start the app';

  @override
  String get startupFailedMessage =>
      'App services couldn\'t be initialized. Try again. If this keeps happening, copy the error details and report them.';

  @override
  String get startupRetry => 'Retry';

  @override
  String get startupCopyDetails => 'Copy error details';

  @override
  String get playerPrevious => 'Previous';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String get playerNext => 'Next';

  @override
  String get playerPlayAll => 'Play all';

  @override
  String get playerLike => 'Like';

  @override
  String get playerUnlike => 'Unlike';

  @override
  String get nowPlayingNotPlaying => 'Nothing playing';

  @override
  String get nowPlayingPickSong => 'Pick a song';

  @override
  String get searchEmptyTitle => 'No results';

  @override
  String searchEmptyQuery(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String get searchEmptyHint => 'Try another keyword';

  @override
  String get commonFollowSystem => 'Follow system';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get accentGraphite => 'Graphite';

  @override
  String get accentDeepPurple => 'Deep purple';

  @override
  String get accentIndigo => 'Indigo';

  @override
  String get accentBlue => 'Blue';

  @override
  String get accentCyan => 'Cyan';

  @override
  String get accentGreen => 'Green';

  @override
  String get accentOrange => 'Orange';

  @override
  String get accentRed => 'Red';

  @override
  String get accentPink => 'Pink';

  @override
  String get accentBlueGrey => 'Blue grey';

  @override
  String get lyricTextSizeSmall => 'Small';

  @override
  String get lyricTextSizeMedium => 'Medium';

  @override
  String get lyricTextSizeLarge => 'Large';

  @override
  String get lyricEffectStandard => 'Default';

  @override
  String get lyricEffectStrong => 'Strong';

  @override
  String get lyricTransitionClassic => 'Classic';

  @override
  String get lyricTransitionClassicDescription => 'Default size transition';

  @override
  String get lyricTransitionScale => 'Scale';

  @override
  String get lyricTransitionScaleDescription => 'Zooms in, then settles';

  @override
  String get lyricTransitionSlide => 'Slide';

  @override
  String get lyricTransitionSlideDescription => 'Slides up and fades in';

  @override
  String get lyricTransitionNone => 'None';

  @override
  String get lyricTransitionNoneDescription => 'Switches instantly';

  @override
  String get lyricAlignmentLeft => 'Left';

  @override
  String get lyricAlignmentRight => 'Right';

  @override
  String get lyricBlurOff => 'Off';

  @override
  String get lyricBlurLight => 'Light';

  @override
  String get lyricBlurStandard => 'Standard';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionLibrary => 'Library';

  @override
  String get settingsSectionPlayback => 'Playback';

  @override
  String get settingsSectionAppearance => 'Appearance';

  @override
  String get settingsSectionGeneral => 'General';

  @override
  String get settingsClearCoverCacheTitle => 'Clear cover cache';

  @override
  String get settingsClearCoverCacheBody =>
      'Deletes cover files that are no longer used by any song or album.\nCovers in use are unaffected.';

  @override
  String get settingsClearCoverCacheAction => 'Clear';

  @override
  String get settingsNotificationsDenied =>
      'Notifications are turned off, so track-change banners won\'t appear';

  @override
  String get settingsOpenSystemSettings => 'Open system settings';

  @override
  String get settingsForceRescanTitle => 'Force rescan';

  @override
  String get settingsForceRescanSubtitle =>
      'Re-parses every song to fix broken metadata or covers';

  @override
  String get settingsForceRescanNoFolders => 'Add a music folder first';

  @override
  String get settingsResumeTitle => 'Resume last position';

  @override
  String get settingsResumeSubtitle =>
      'Restores your previous playback position on launch';

  @override
  String get settingsTrackNotificationTitle =>
      'Show a system notification on track change';

  @override
  String get settingsTrackNotificationSubtitle =>
      'Only appears in the background or when the window is closed';

  @override
  String get settingsSleepFinishTrackTitle =>
      'Finish the current track before sleeping';

  @override
  String get settingsSleepFinishTrackSubtitle =>
      'When off, playback fades out and pauses when the timer ends';

  @override
  String get settingsAccentTitle => 'Accent color';

  @override
  String get settingsAccentSubtitle =>
      'Pick an accent color or follow the system';

  @override
  String get settingsThemeTitle => 'Theme';

  @override
  String get settingsThemeSubtitle =>
      'Choose the app\'s light or dark appearance';

  @override
  String get settingsLyricsTitle => 'Lyrics display';

  @override
  String get settingsLyricsSubtitle =>
      'Text size, translation and lyric effects';

  @override
  String get settingsNowPlayingFillTitle => 'Progress fill in the player bar';

  @override
  String get settingsNowPlayingFillSubtitle =>
      'The bar background fills left to right while playing';

  @override
  String get settingsLogsTitle => 'Logs';

  @override
  String get settingsLogsSubtitle => 'View app runtime logs';

  @override
  String get settingsCacheTitle => 'Cache';

  @override
  String get settingsCacheSubtitle => 'Cover image cache (safe to clear)';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get lyricsSettingsTitle => 'Lyrics display';

  @override
  String get lyricsTextSizeTitle => 'Text size';

  @override
  String get lyricsTextSizeSubtitle => 'Adjust lyric and translation text size';

  @override
  String get lyricsTranslationTitle => 'Translation line';

  @override
  String get lyricsTranslationSubtitle =>
      'Shows a translation under the original when available';

  @override
  String get lyricsWordFillTitle => 'Per-character fill';

  @override
  String get lyricsWordFillSubtitle =>
      'Fills each sung character with the accent color';

  @override
  String get lyricsWordLiftTitle => 'Word pop';

  @override
  String get lyricsWordLiftSubtitle =>
      'Each sung character jumps up and stays raised for the line';

  @override
  String get lyricsEffectStrengthTitle => 'Effect strength';

  @override
  String get lyricsEffectStrengthSubtitle => 'How high each character jumps';

  @override
  String get lyricsWordTimingHint =>
      'Plain LRC simulates per-character timing. QRC / YRC use the word timings stored in the file.';

  @override
  String get lyricsTransitionTitle => 'Line transition';

  @override
  String get lyricsAlignmentTitle => 'Alignment';

  @override
  String get lyricsAlignmentSubtitle =>
      'Slide direction follows the aligned edge';

  @override
  String get lyricsLineWaveTitle => 'Line wave';

  @override
  String get lyricsLineWaveSubtitle => 'Lines shift and rise in sequence';

  @override
  String get lyricsLineWaveHint =>
      'Applies to whole lines and stacks with word pop; turning on both can look busy.';

  @override
  String get lyricsBlurTitle => 'Distance blur';

  @override
  String get lyricsBlurSubtitle =>
      'Lines blur more the farther they are from the current one; stays sharp while browsing';

  @override
  String get lyricsBlurHint =>
      'Adds one off-screen blur layer per line. Turn it off on slower machines or when stacking many effects.';

  @override
  String get lyricsCountdownTitle => 'Countdown dots';

  @override
  String get lyricsCountdownSubtitle =>
      'Shows three fading dots for intros and interludes';

  @override
  String get lyricsCountdownHint =>
      'Plain LRC needs a blank timestamp at the interlude (for example [00:12.00]) to show them.';

  @override
  String get lyricsSectionText => 'Text';

  @override
  String get lyricsSectionEffects => 'Text effects';

  @override
  String get lyricsSectionLineMotion => 'Line motion';

  @override
  String get lyricsPreviewLoop => 'Loop preview';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutTagline => 'Local music player';

  @override
  String get aboutLicenses => 'Open-source licenses';

  @override
  String get aboutProjectHome => 'Project home';

  @override
  String get aboutLinkCopied => 'Project link copied';

  @override
  String get logsTitle => 'Logs';

  @override
  String get logsSelectDate => 'Select date';

  @override
  String get logsEmpty => 'No logs yet';

  @override
  String get logsDebugHint =>
      'This is a debug build, so logs only go to the console and don\'t appear here. Release and profile builds write log files.';

  @override
  String get logDetailTitle => 'Log details';

  @override
  String settingsCoverCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Removed $count unused covers',
      one: 'Removed 1 unused cover',
      zero: 'No unused covers to clear',
    );
    return '$_temp0';
  }

  @override
  String settingsAboutSubtitle(String version) {
    return 'Version $version · Open-source licenses';
  }

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get lyricsSectionCountdown => 'Countdown';

  @override
  String get commonListSeparator => ', ';

  @override
  String get libraryTitle => 'Library';

  @override
  String get libraryYourLibrary => 'Your library';

  @override
  String get libraryEmptyHint => 'Import a music folder to get started';

  @override
  String get libraryImportFolder => 'Import folder';

  @override
  String get libraryAccessExpired =>
      'Music folder access has expired. Grant access again.';

  @override
  String get libraryRegrant => 'Grant access again';

  @override
  String get librarySearchSongsHint => 'Search songs';

  @override
  String get librarySort => 'Sort';

  @override
  String get libraryRescan => 'Rescan';

  @override
  String get libraryScanningFolders => 'Scanning folders…';

  @override
  String get libraryProcessing => 'Processing…';

  @override
  String get libraryRescanFolder => 'Rescan this folder';

  @override
  String get libraryRemoveFolder => 'Remove';

  @override
  String get libraryScanNoNew => 'No new files';

  @override
  String get albumTitle => 'Albums';

  @override
  String get albumVariousArtists => 'Various artists';

  @override
  String get albumSearchHint => 'Search albums';

  @override
  String get albumEmptyTitle => 'No albums yet';

  @override
  String get albumEmptyHint =>
      'Albums are grouped automatically after you import a music folder';

  @override
  String get albumAddToQueue => 'Add to queue';

  @override
  String get albumNoPlayable => 'This album has no playable songs';

  @override
  String get artistTitle => 'Artists';

  @override
  String get artistSearchHint => 'Search artists';

  @override
  String get artistEmptyTitle => 'No artists yet';

  @override
  String get artistEmptyHint =>
      'Artists are grouped automatically after you import a music folder';

  @override
  String get artistNoPlayable => 'This artist has no playable songs';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortDateAdded => 'Recently added';

  @override
  String get sortPlayCount => 'Most played';

  @override
  String get sortYear => 'Year';

  @override
  String librarySongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String librarySongMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matched $count songs',
      one: 'Matched 1 song',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String libraryScanAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count songs',
      one: 'Added 1 song',
    );
    return '$_temp0';
  }

  @override
  String libraryScanUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Updated $count songs',
      one: 'Updated 1 song',
    );
    return '$_temp0';
  }

  @override
  String libraryScanRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs removed',
      one: '1 song removed',
    );
    return '$_temp0';
  }

  @override
  String libraryScanPurged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cleared $count leftover rows',
      one: 'Cleared 1 leftover row',
    );
    return '$_temp0';
  }

  @override
  String libraryScanErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count failures',
      one: '1 failure',
    );
    return '$_temp0';
  }

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
      zero: 'No albums',
    );
    return '$_temp0';
  }

  @override
  String albumMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matched $count albums',
      one: 'Matched 1 album',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String albumSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
      zero: 'No songs',
    );
    return '$_temp0';
  }

  @override
  String artistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count artists',
      one: '1 artist',
      zero: 'No artists',
    );
    return '$_temp0';
  }

  @override
  String artistMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matched $count artists',
      one: 'Matched 1 artist',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String artistSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count songs',
      one: '1 song',
    );
    return '$_temp0';
  }

  @override
  String artistAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count albums',
      one: '1 album',
    );
    return '$_temp0';
  }

  @override
  String artistSectionAlbums(int count) {
    return 'Albums ($count)';
  }

  @override
  String artistSectionSongs(int count) {
    return 'Songs ($count)';
  }

  @override
  String libraryParsingMetadata(int processed, int total) {
    return 'Parsing metadata $processed/$total…';
  }

  @override
  String libraryScanDone(String summary) {
    return 'Scan complete: $summary';
  }

  @override
  String libraryScanFailed(String error) {
    return 'Scan failed: $error';
  }

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonName => 'Name';

  @override
  String get playlistTitle => 'Playlists';

  @override
  String get playlistSearchHint => 'Search playlists';

  @override
  String get playlistNew => 'New playlist';

  @override
  String get playlistCreateHint => 'For example: My favorites';

  @override
  String get playlistImport => 'Import playlist';

  @override
  String get playlistImportReadFailed =>
      'Import failed: couldn\'t read the file';

  @override
  String get playlistImportNoMatches =>
      'No songs matched. Make sure the playlist\'s files are in your library.';

  @override
  String get playlistExportEmpty => 'No playlists to export';

  @override
  String get playlistChooseExport => 'Choose a playlist to export';

  @override
  String get playlistExportFailed =>
      'Export failed: couldn\'t build the playlist content';

  @override
  String get playlistExport => 'Export playlist';

  @override
  String get playlistRename => 'Rename playlist';

  @override
  String get playlistDelete => 'Delete playlist';

  @override
  String get playlistEmpty => 'This playlist is empty';

  @override
  String get playlistEmptyHint =>
      'Use the \"Add songs\" button in the top-right corner to add songs';

  @override
  String get playlistMyPlaylists => 'My playlists';

  @override
  String get playlistFavorites => 'Favorites';

  @override
  String get playlistListEmpty => 'No playlists yet';

  @override
  String get playlistListEmptyHint =>
      'Tap + in the top-right corner to create a playlist';

  @override
  String get playlistImportIntoExisting => 'Add to an existing playlist';

  @override
  String get playlistFavoritesEmpty => 'No favorites yet';

  @override
  String get playlistFavoritesEmptyHint =>
      'Use \"Like\" in a song\'s \"More\" menu to add it';

  @override
  String get playlistAddSongs => 'Add songs';

  @override
  String get playlistManualSort => 'Manual sort';

  @override
  String get playlistDoneSorting => 'Done sorting';

  @override
  String get playlistExportM3u => 'Export as M3U…';

  @override
  String get playlistSortByName => 'Sort by name';

  @override
  String get playlistMenuExport => 'Export';

  @override
  String get playlistMenuRename => 'Rename';

  @override
  String get playlistRemoveFrom => 'Remove from playlist';

  @override
  String get playlistAddTo => 'Add to playlist';

  @override
  String get playlistPickerEmpty => 'No playlists yet. Create one first.';

  @override
  String get playlistNewEllipsis => 'New playlist…';

  @override
  String get playlistNoMatchingSongs => 'No matching songs';

  @override
  String get playlistSelectSongs => 'Select songs';

  @override
  String get songAddToQueue => 'Add to queue';

  @override
  String get songPlayNext => 'Play next';

  @override
  String get songStartedPlaying => 'Started playing';

  @override
  String get songAddedNext => 'Added to play next';

  @override
  String get songAddedQueue => 'Added to the queue';

  @override
  String playlistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count playlists',
      one: '1 playlist',
      zero: 'No playlists',
    );
    return '$_temp0';
  }

  @override
  String playlistMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matched $count playlists',
      one: 'Matched 1 playlist',
      zero: 'No matches',
    );
    return '$_temp0';
  }

  @override
  String playlistImported(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Imported $count songs into \"$name\"',
      one: 'Imported 1 song into \"$name\"',
    );
    return '$_temp0';
  }

  @override
  String playlistImportUnmatched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unmatched (not in your library)',
      one: '1 unmatched (not in your library)',
    );
    return '$_temp0';
  }

  @override
  String playlistImportSheetTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Import $count songs',
      one: 'Import 1 song',
    );
    return '$_temp0';
  }

  @override
  String playlistExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Exported $count songs',
      one: 'Exported 1 song',
    );
    return '$_temp0';
  }

  @override
  String playlistAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add ($count)',
      one: 'Add (1)',
      zero: 'Select songs',
    );
    return '$_temp0';
  }

  @override
  String get playlistFallbackName => 'Playlist';

  @override
  String playlistSkippedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unmatched',
      one: '1 unmatched',
    );
    return '$_temp0';
  }

  @override
  String playlistCreateNamed(String name) {
    return 'New playlist \"$name\"';
  }

  @override
  String playlistDeleteConfirm(String name) {
    return 'Delete \"$name\"? This can\'t be undone.';
  }
}
