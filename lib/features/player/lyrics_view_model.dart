import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:path/path.dart' as p;

import '../../core/database/database.dart';
import '../../core/services/player_service.dart';
import '../../core/utils/bilingual_lrc.dart';
import '../../core/utils/logger.dart';

/// 歌词路径解析：数据库的 [Song.lyricsFilePath] 优先；否则实时按音频文件找
/// 同名 `.lrc`/`.LRC`（与 `MetadataService._findLrcFile` 一致）。
///
/// 顶层函数便于单元测试（不依赖 PlayerService 构造）。
String? resolveLrcPath(Song song) {
  final dbPath = song.lyricsFilePath;
  if (dbPath != null && File(dbPath).existsSync()) return dbPath;
  final dir = p.dirname(song.filePath);
  final base = p.basenameWithoutExtension(song.filePath);
  for (final ext in const ['.lrc', '.LRC']) {
    final f = File(p.join(dir, '$base$ext'));
    if (f.existsSync()) return f.path;
  }
  return null;
}

/// 歌词视图模型：驱动 flutter_lyric 的 [LyricController]。
///
/// - 监听当前歌曲变化（[PlayerService.currentSongNotifier]，按歌曲去重）→
///   读取 `.lrc` → [LyricController.loadLyric]；
/// - 监听播放进度（[PlayerService.positionStream]）→ [LyricController.setProgress]，
///   驱动歌词高亮与滚动。
///
/// 歌词路径解析：[Song.lyricsFilePath]（数据库扫描时记录）优先；不存在时
/// 实时按音频文件找同名 `.lrc`/`.LRC` 兜底，因此新放的歌词文件无需重新扫描。
class LyricsViewModel {
  /// 高亮/滚动切换到下一行的提前量（毫秒）：正值让歌词高亮比实际时间戳
  /// 早一点切换，跟唱更顺；不影响点击歌词 seek（其回调用原始时间戳）。
  static const int _kLyricOffsetMs = 300;

  /// 默认判定：平台 locale 是否为中文。
  static bool _defaultIsChineseUi() {
    final lang = PlatformDispatcher.instance.locale.languageCode.toLowerCase();
    return lang == 'zh';
  }

  LyricsViewModel(PlayerService player, {bool Function()? isChineseUi})
    : _player = player,
      _isChineseUi = isChineseUi ?? _defaultIsChineseUi {
    // 高亮/滚动提前一点切换（跟唱更顺）。
    controller.lyricOffset = _kLyricOffsetMs;
    _player.currentSongNotifier.addListener(_onSongChanged);
    _positionSub = _player.positionStream.listen(_onPosition);
    // 初始加载当前歌曲（若打开播放页前已有歌在播）。
    _onSongChanged();
    // 恢复播放位置同步到歌词：未播放/序列未加载时 positionStream 不发事件，
    // 必须主动读一次当前（含续播）位置，否则歌词停在开头直到点播放才跳转。
    _syncPosition();
  }

  final PlayerService _player;

  /// 界面语言判定：是否为中文（决定是否显示 `.lrc` 的中文翻译副行）。
  /// 可注入以便测试；默认取平台 locale。
  final bool Function() _isChineseUi;

  /// flutter_lyric 控制器（[LyricsView] 直接消费）。
  final LyricController controller = LyricController();

  StreamSubscription<Duration>? _positionSub;

  /// 正在加载歌词的歌曲 id（防快速切歌时过期结果覆盖新歌）。
  int? _loadingForId;

  /// 是否显示翻译副行（由歌词菜单栏开关控制）。
  bool _showTranslation = true;

  /// 切换翻译副行显隐（重新加载当前歌词）。
  void setShowTranslation(bool show) {
    if (show == _showTranslation) return;
    _showTranslation = show;
    _loadForSong(_player.currentSong);
  }

  void _onSongChanged() {
    _loadForSong(_player.currentSong);
  }

  void _onPosition(Duration position) {
    controller.setProgress(position);
  }

  /// 用当前播放位置（含未播放时的恢复/保存位置）同步歌词高亮。
  void _syncPosition() {
    controller.setProgress(_player.position);
  }

  Future<void> _loadForSong(Song? song) async {
    final songId = song?.id;
    _loadingForId = songId;

    final path = song == null ? null : resolveLrcPath(song);
    if (path == null) {
      // 无歌词：清空上次歌词（LyricView 据此显示"暂无歌词"占位）。
      controller.loadLyric('');
      return;
    }

    try {
      final content = await File(path).readAsString();
      // 竞态校验：读取期间切了歌则丢弃本次结果。
      if (_loadingForId != songId) return;
      // 同行双语（原文 翻译）自动拆成主歌词 + 翻译两条时间轴；
      // 无翻译时 translationLyric 为空串，flutter_lyric 按无翻译处理。
      final split = splitBilingualLrc(content);
      controller.loadLyric(
        split.mainLyric,
        // 翻译副行：翻译开关开启 且 界面语言为中文 才显示（英文界面暂未提供
        // 英文翻译源，隐藏中文翻译副行）；否则传空串按无翻译渲染。
        translationLyric: _showTranslation && _isChineseUi()
            ? split.translationLyric
            : '',
      );
      // 歌词就绪后再对齐一次位置（防御 positionStream 先发 0 的时序）。
      _syncPosition();
    } catch (e, s) {
      AppLogger.warning('Lyric', 'Failed to load lyrics: $path', e, s);
      if (_loadingForId != songId) return;
      controller.loadLyric('');
    }
  }

  void dispose() {
    _player.currentSongNotifier.removeListener(_onSongChanged);
    _positionSub?.cancel();
    controller.dispose();
  }
}
