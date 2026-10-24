// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get settingsLanguageTitle => '语言';

  @override
  String get settingsLanguageSubtitle => '应用界面语言';

  @override
  String get settingsLanguageSystem => '跟随系统';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageSimplifiedChinese => '简体中文';

  @override
  String get commonBack => '返回';

  @override
  String get commonClear => '清空';

  @override
  String get commonCloseSearch => '关闭搜索';

  @override
  String get commonMore => '更多';

  @override
  String get commonSearch => '搜索';

  @override
  String get navLibrary => '音乐库';

  @override
  String get navAlbums => '专辑';

  @override
  String get navArtists => '歌手';

  @override
  String get navPlaylists => '播放列表';

  @override
  String get navSettings => '设置';

  @override
  String get startupFailedTitle => '应用启动失败';

  @override
  String get startupFailedMessage => '无法初始化应用服务，请重试。若持续失败，请复制错误详情并反馈。';

  @override
  String get startupRetry => '重试';

  @override
  String get startupCopyDetails => '复制错误详情';

  @override
  String get playerPrevious => '上一首';

  @override
  String get playerPlay => '播放';

  @override
  String get playerPause => '暂停';

  @override
  String get playerNext => '下一首';

  @override
  String get playerPlayAll => '播放全部';

  @override
  String get playerLike => '喜欢';

  @override
  String get playerUnlike => '取消喜欢';

  @override
  String get nowPlayingNotPlaying => '未在播放';

  @override
  String get nowPlayingPickSong => '选择一首歌曲';

  @override
  String get searchEmptyTitle => '没有找到相关内容';

  @override
  String searchEmptyQuery(String query) {
    return '没有找到与「$query」相关的内容';
  }

  @override
  String get searchEmptyHint => '换个关键词试试';
}
