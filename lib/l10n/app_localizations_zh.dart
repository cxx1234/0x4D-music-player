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

  @override
  String get commonFollowSystem => '跟随系统';

  @override
  String get commonCancel => '取消';

  @override
  String get accentGraphite => '石墨灰';

  @override
  String get accentDeepPurple => '深紫';

  @override
  String get accentIndigo => '靛蓝';

  @override
  String get accentBlue => '蓝';

  @override
  String get accentCyan => '青';

  @override
  String get accentGreen => '绿';

  @override
  String get accentOrange => '橙';

  @override
  String get accentRed => '红';

  @override
  String get accentPink => '粉';

  @override
  String get accentBlueGrey => '蓝灰';

  @override
  String get lyricTextSizeSmall => '小';

  @override
  String get lyricTextSizeMedium => '中';

  @override
  String get lyricTextSizeLarge => '大';

  @override
  String get lyricEffectStandard => '默认';

  @override
  String get lyricEffectStrong => '强';

  @override
  String get lyricTransitionClassic => '经典';

  @override
  String get lyricTransitionClassicDescription => '默认的尺寸过渡';

  @override
  String get lyricTransitionScale => '缩放';

  @override
  String get lyricTransitionScaleDescription => '放大后微微收束';

  @override
  String get lyricTransitionSlide => '滑入';

  @override
  String get lyricTransitionSlideDescription => '从下方滑入并淡入';

  @override
  String get lyricTransitionNone => '无';

  @override
  String get lyricTransitionNoneDescription => '立即切换，不做动画';

  @override
  String get lyricAlignmentLeft => '左';

  @override
  String get lyricAlignmentRight => '右';

  @override
  String get lyricBlurOff => '关';

  @override
  String get lyricBlurLight => '轻';

  @override
  String get lyricBlurStandard => '标准';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsSectionLibrary => '音乐库';

  @override
  String get settingsSectionPlayback => '播放设置';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsClearCoverCacheTitle => '清理封面缓存';

  @override
  String get settingsClearCoverCacheBody =>
      '将删除不再被任何歌曲或专辑引用的封面文件。\n正在使用的封面不受影响。';

  @override
  String get settingsClearCoverCacheAction => '清理';

  @override
  String get settingsNotificationsDenied => '通知权限未开启，切歌通知不会显示';

  @override
  String get settingsOpenSystemSettings => '打开系统设置';

  @override
  String get settingsForceRescanTitle => '强制刷新';

  @override
  String get settingsForceRescanSubtitle => '重新解析全部歌曲，修复异常元数据/封面';

  @override
  String get settingsForceRescanNoFolders => '请先在音乐库添加文件夹';

  @override
  String get settingsResumeTitle => '续播上次播放位置';

  @override
  String get settingsResumeSubtitle => '启动后恢复上次播放进度';

  @override
  String get settingsTrackNotificationTitle => '切歌时显示系统通知';

  @override
  String get settingsTrackNotificationSubtitle => '只应用在后台/关窗时弹出，前台不打扰';

  @override
  String get settingsSleepFinishTrackTitle => '睡眠定时先播完当前曲';

  @override
  String get settingsSleepFinishTrackSubtitle => '关闭则到点立即淡出暂停';

  @override
  String get settingsAccentTitle => '主题色';

  @override
  String get settingsAccentSubtitle => '选择界面强调色或跟随系统';

  @override
  String get settingsThemeTitle => '主题模式';

  @override
  String get settingsThemeSubtitle => '选择应用的明暗外观';

  @override
  String get settingsLyricsTitle => '歌词显示';

  @override
  String get settingsLyricsSubtitle => '字号、翻译与歌词动效';

  @override
  String get settingsNowPlayingFillTitle => '底栏播放进度填充';

  @override
  String get settingsNowPlayingFillSubtitle => '播放时底栏背景从左向右显示进度';

  @override
  String get settingsLogsTitle => '日志';

  @override
  String get settingsLogsSubtitle => '查看应用运行日志';

  @override
  String get settingsCacheTitle => '缓存';

  @override
  String get settingsCacheSubtitle => '封面图片缓存（可安全清理）';

  @override
  String get settingsAboutTitle => '关于';

  @override
  String get lyricsSettingsTitle => '歌词显示';

  @override
  String get lyricsTextSizeTitle => '字号';

  @override
  String get lyricsTextSizeSubtitle => '调整歌词与翻译的文字大小';

  @override
  String get lyricsTranslationTitle => '翻译副行';

  @override
  String get lyricsTranslationSubtitle => '有翻译时在原文下方显示';

  @override
  String get lyricsWordFillTitle => '逐字填充';

  @override
  String get lyricsWordFillSubtitle => '唱到的字逐渐填充主题色';

  @override
  String get lyricsWordLiftTitle => '逐字跳动';

  @override
  String get lyricsWordLiftSubtitle => '唱到的字向上跳一下（本句内保持）';

  @override
  String get lyricsEffectStrengthTitle => '效果强度';

  @override
  String get lyricsEffectStrengthSubtitle => '逐字跳起的高度';

  @override
  String get lyricsWordTimingHint => '普通 LRC 会自动模拟逐字时间；QRC / YRC 使用歌词自带的词级时间。';

  @override
  String get lyricsTransitionTitle => '切句动画';

  @override
  String get lyricsAlignmentTitle => '对齐';

  @override
  String get lyricsAlignmentSubtitle => '滑动方向跟随对齐边';

  @override
  String get lyricsLineWaveTitle => '行间波浪';

  @override
  String get lyricsLineWaveSubtitle => '整行依次错位并轻微起伏';

  @override
  String get lyricsLineWaveHint => '作用在整行上，和逐字跳动可以叠加；同时开启可能偏花。';

  @override
  String get lyricsBlurTitle => '距离模糊';

  @override
  String get lyricsBlurSubtitle => '离当前句越远越模糊；浏览时保持清晰';

  @override
  String get lyricsBlurHint => '每行会多一个离屏模糊层；低配设备或叠加大量动效时建议关闭。';

  @override
  String get lyricsCountdownTitle => '倒计时圆点';

  @override
  String get lyricsCountdownSubtitle => '前奏/间奏显示三个渐隐圆点';

  @override
  String get lyricsCountdownHint => '普通 LRC 需要在间奏处留空白时间戳（如 [00:12.00]）才会显示。';

  @override
  String get lyricsSectionText => '文字';

  @override
  String get lyricsSectionEffects => '文本效果';

  @override
  String get lyricsSectionLineMotion => '行间动效';

  @override
  String get lyricsPreviewLoop => '循环预览';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutTagline => '本地音乐播放器';

  @override
  String get aboutLicenses => '开源许可';

  @override
  String get aboutProjectHome => '项目主页';

  @override
  String get aboutLinkCopied => '已复制项目链接';

  @override
  String get logsTitle => '日志';

  @override
  String get logsSelectDate => '选择日期';

  @override
  String get logsEmpty => '暂无日志';

  @override
  String get logsDebugHint =>
      '当前为 Debug 构建,日志仅输出到控制台,不会写入本页。Release/Profile 构建才会生成日志文件。';

  @override
  String get logDetailTitle => '日志详情';

  @override
  String settingsCoverCacheCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已清理 $count 个未使用的封面',
      zero: '没有可清理的封面缓存',
    );
    return '$_temp0';
  }

  @override
  String settingsAboutSubtitle(String version) {
    return '版本 $version · 开源许可';
  }

  @override
  String aboutVersion(String version) {
    return '版本 $version';
  }

  @override
  String get lyricsSectionCountdown => '倒计时';

  @override
  String get commonListSeparator => '，';

  @override
  String get libraryTitle => '音乐库';

  @override
  String get libraryYourLibrary => '你的音乐库';

  @override
  String get libraryEmptyHint => '导入音乐文件夹以开始使用';

  @override
  String get libraryImportFolder => '导入文件夹';

  @override
  String get libraryAccessExpired => '音乐文件夹访问权限已失效，请重新授权';

  @override
  String get libraryRegrant => '重新授权';

  @override
  String get librarySearchSongsHint => '搜索歌曲';

  @override
  String get librarySort => '排序';

  @override
  String get libraryRescan => '重新扫描';

  @override
  String get libraryScanningFolders => '正在扫描文件夹...';

  @override
  String get libraryProcessing => '正在处理...';

  @override
  String get libraryRescanFolder => '重新扫描此文件夹';

  @override
  String get libraryRemoveFolder => '移除';

  @override
  String get libraryScanNoNew => '无新文件';

  @override
  String get albumTitle => '专辑';

  @override
  String get albumVariousArtists => '多位歌手';

  @override
  String get albumSearchHint => '搜索专辑';

  @override
  String get albumEmptyTitle => '暂无专辑';

  @override
  String get albumEmptyHint => '导入音乐文件夹后会自动按专辑归类';

  @override
  String get albumAddToQueue => '添加到播放队列';

  @override
  String get albumNoPlayable => '专辑里没有可播放的歌曲';

  @override
  String get artistTitle => '歌手';

  @override
  String get artistSearchHint => '搜索歌手';

  @override
  String get artistEmptyTitle => '暂无歌手';

  @override
  String get artistEmptyHint => '导入音乐文件夹后会自动按歌手归类';

  @override
  String get artistNoPlayable => '这位歌手还没有可播放的歌曲';

  @override
  String get sortTitle => '标题';

  @override
  String get sortDateAdded => '最近添加';

  @override
  String get sortPlayCount => '常听';

  @override
  String get sortYear => '年份';

  @override
  String librarySongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首',
    );
    return '$_temp0';
  }

  @override
  String librarySongMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '匹配 $count 首',
    );
    return '$_temp0';
  }

  @override
  String libraryScanAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添加 $count 首',
    );
    return '$_temp0';
  }

  @override
  String libraryScanUpdated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '更新 $count 首',
    );
    return '$_temp0';
  }

  @override
  String libraryScanRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首已移除',
    );
    return '$_temp0';
  }

  @override
  String libraryScanPurged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '清理 $count 条残留',
    );
    return '$_temp0';
  }

  @override
  String libraryScanErrors(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 处失败',
    );
    return '$_temp0';
  }

  @override
  String albumCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张',
    );
    return '$_temp0';
  }

  @override
  String albumMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '匹配 $count 张',
    );
    return '$_temp0';
  }

  @override
  String albumSongCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String artistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 位',
    );
    return '$_temp0';
  }

  @override
  String artistMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '匹配 $count 位',
    );
    return '$_temp0';
  }

  @override
  String artistSongs(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String artistAlbums(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 张专辑',
    );
    return '$_temp0';
  }

  @override
  String artistSectionAlbums(int count) {
    return '专辑 ($count)';
  }

  @override
  String artistSectionSongs(int count) {
    return '歌曲 ($count)';
  }

  @override
  String libraryParsingMetadata(int processed, int total) {
    return '正在解析元数据 $processed/$total...';
  }

  @override
  String libraryScanDone(String summary) {
    return '扫描完成：$summary';
  }

  @override
  String libraryScanFailed(String error) {
    return '扫描失败：$error';
  }

  @override
  String get commonSave => '保存';

  @override
  String get commonDelete => '删除';

  @override
  String get commonCreate => '创建';

  @override
  String get commonName => '名称';

  @override
  String get playlistTitle => '播放列表';

  @override
  String get playlistSearchHint => '搜索播放列表';

  @override
  String get playlistNew => '新建播放列表';

  @override
  String get playlistCreateHint => '例如：我的最爱';

  @override
  String get playlistImport => '导入播放列表';

  @override
  String get playlistImportReadFailed => '导入失败：无法读取文件';

  @override
  String get playlistImportNoMatches => '未匹配到任何歌曲，请确认歌单中的文件已在音乐库中';

  @override
  String get playlistExportEmpty => '没有可导出的播放列表';

  @override
  String get playlistChooseExport => '选择要导出的播放列表';

  @override
  String get playlistExportFailed => '导出失败：无法生成播放列表内容';

  @override
  String get playlistExport => '导出播放列表';

  @override
  String get playlistRename => '重命名播放列表';

  @override
  String get playlistDelete => '删除播放列表';

  @override
  String get playlistEmpty => '播放列表为空';

  @override
  String get playlistEmptyHint => '点击右上角\"添加歌曲\"按钮加入歌曲';

  @override
  String get playlistMyPlaylists => '我的播放列表';

  @override
  String get playlistFavorites => '我的收藏';

  @override
  String get playlistListEmpty => '暂无播放列表';

  @override
  String get playlistListEmptyHint => '点击右上角 + 新建播放列表';

  @override
  String get playlistImportIntoExisting => '加入已有播放列表';

  @override
  String get playlistFavoritesEmpty => '还没有收藏的歌曲';

  @override
  String get playlistFavoritesEmptyHint => '在歌曲的\"更多\"菜单里点\"喜欢\"即可收藏';

  @override
  String get playlistAddSongs => '添加歌曲';

  @override
  String get playlistManualSort => '手动排序';

  @override
  String get playlistDoneSorting => '完成排序';

  @override
  String get playlistExportM3u => '导出为 M3U…';

  @override
  String get playlistSortByName => '按名称排序';

  @override
  String get playlistMenuExport => '导出';

  @override
  String get playlistMenuRename => '重命名';

  @override
  String get playlistRemoveFrom => '从播放列表移除';

  @override
  String get playlistAddTo => '添加到播放列表';

  @override
  String get playlistPickerEmpty => '还没有播放列表，先新建一个吧';

  @override
  String get playlistNewEllipsis => '新建播放列表…';

  @override
  String get playlistNoMatchingSongs => '没有匹配的歌曲';

  @override
  String get playlistSelectSongs => '选择歌曲';

  @override
  String get songAddToQueue => '添加到播放队列';

  @override
  String get songPlayNext => '下一首播放';

  @override
  String get songStartedPlaying => '已开始播放';

  @override
  String get songAddedNext => '已加入下一首播放';

  @override
  String get songAddedQueue => '已添加到播放队列';

  @override
  String playlistCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个',
    );
    return '$_temp0';
  }

  @override
  String playlistMatch(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '匹配 $count 个',
    );
    return '$_temp0';
  }

  @override
  String playlistImported(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导入 $count 首到\"$name\"',
    );
    return '$_temp0';
  }

  @override
  String playlistImportUnmatched(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首未匹配（不在音乐库中）',
    );
    return '$_temp0';
  }

  @override
  String playlistImportSheetTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '导入 $count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String playlistExported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已导出 $count 首歌曲',
    );
    return '$_temp0';
  }

  @override
  String playlistAddSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '添加 ($count)',
      zero: '选择歌曲',
    );
    return '$_temp0';
  }

  @override
  String get playlistFallbackName => '播放列表';

  @override
  String playlistSkippedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 首未匹配',
    );
    return '$_temp0';
  }

  @override
  String playlistCreateNamed(String name) {
    return '新建播放列表\"$name\"';
  }

  @override
  String playlistDeleteConfirm(String name) {
    return '确定删除\"$name\"吗？此操作不可撤销。';
  }

  @override
  String get commonClose => '关闭';

  @override
  String get playerCollapse => '收起';

  @override
  String get playerNowPlaying => '正在播放';

  @override
  String get playerLyricsTab => '歌词';

  @override
  String get playerQueueTab => '播放列表';

  @override
  String get playerPickSongToStart => '选择一首歌曲开始播放';

  @override
  String get lyricsTitle => '歌词';

  @override
  String get lyricsTextSizeTooltip => '文本大小';

  @override
  String get lyricsSettingsTooltip => '歌词显示设置';

  @override
  String get lyricsHideTranslation => '关闭翻译';

  @override
  String get lyricsShowTranslation => '显示翻译';

  @override
  String get lyricsEmpty => '暂无歌词';

  @override
  String get queueSequential => '顺序播放';

  @override
  String get queueShuffle => '随机播放';

  @override
  String get queueRepeatAll => '循环列表播放';

  @override
  String get queueRepeatOne => '单曲循环播放';

  @override
  String get queueAtBottomSuffix => ' · 到底了';

  @override
  String get queueClearTitle => '清空播放列表';

  @override
  String get queueClearConfirm => '确定要清空当前播放列表吗？';

  @override
  String get queueClearTooltip => '清空列表';

  @override
  String get queueRemove => '从队列移除';

  @override
  String get queueEmpty => '播放列表为空';

  @override
  String get queueLocate => '定位到当前播放';

  @override
  String queueDeleteSelected(int count) {
    return '删除选中 ($count)';
  }

  @override
  String get queueSelectDelete => '选择删除';

  @override
  String get queueSingleRepeat => '单曲循环';

  @override
  String get queueModeRepeatAll => '列表循环';

  @override
  String get sleepTimerTitle => '睡眠定时';

  @override
  String get sleepTimerFading => '淡出中';

  @override
  String get sleepTimerEndOfTrack => '播完当前曲目';

  @override
  String get sleepTimerEndOfQueue => '播完当前播放列表';

  @override
  String get sleepTimerFadingLabel => '正在淡出…';

  @override
  String get feedbackPlaying => '播放中';

  @override
  String get feedbackPaused => '已暂停';

  @override
  String get feedbackFirstTrack => '已是第一首';

  @override
  String get feedbackLastTrack => '已是最后一首';

  @override
  String get feedbackStopped => '已停止 · 保留队列';

  @override
  String get feedbackSleepTimerCancelled => '已取消睡眠定时';

  @override
  String get feedbackNoTrack => '没有播放中的歌曲';

  @override
  String get playbackFailedNoTitle => '无法播放该文件，已自动跳过';

  @override
  String get sleepTimerExpiredWaiting => '睡眠定时到点，播完当前曲目后停止';

  @override
  String get sleepTimerFinishedPaused => '睡眠定时结束，已暂停';

  @override
  String get sleepTimerFinishedStopped => '睡眠定时结束，已停止播放';

  @override
  String queueTotalCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '共 $count 首',
    );
    return '$_temp0';
  }

  @override
  String sleepTimerMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟',
    );
    return '$_temp0';
  }

  @override
  String playbackFailedRepeated(int count) {
    return '连续 $count 次无法播放，已停止自动跳转';
  }

  @override
  String queuePlayModeTooltip(String mode) {
    return '播放模式：$mode';
  }

  @override
  String sleepTimerCancel(String state) {
    return '取消定时（$state）';
  }

  @override
  String sleepTimerActiveTooltip(String state) {
    return '睡眠定时 · $state';
  }

  @override
  String feedbackSleepTimerHud(String state) {
    return '睡眠定时 · $state';
  }

  @override
  String playbackFailedWithTitle(String title) {
    return '无法播放：$title，已自动跳过';
  }
}
