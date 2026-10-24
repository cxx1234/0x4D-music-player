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
}
