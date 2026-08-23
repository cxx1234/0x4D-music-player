import 'dart:async';
import 'dart:io';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_lyric/core/lyric_model.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:path/path.dart' as p;

import '../../core/database/database.dart';
import '../../core/services/metadata_service.dart';
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

  LyricsViewModel(
    PlayerService player, {
    bool Function()? isChineseUi,
    MetadataService? metadataService,
  }) : _player = player,
       _isChineseUi = isChineseUi ?? _defaultIsChineseUi,
       _metadata = metadataService ?? MetadataService() {
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

  /// 元数据服务（读内嵌歌词）。可注入以便测试。
  final MetadataService _metadata;

  /// 内嵌歌词内存缓存（按文件路径），带文件修改时间时效：文件变化自动失效。
  final Map<String, ({String content, int modifiedMs})> _embeddedLyricsCache =
      {};

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

    if (song == null) {
      // 无歌词：清空上次歌词（LyricView 据此显示"暂无歌词"占位）。
      controller.loadLyric('');
      return;
    }

    // 歌词来源优先级：内嵌歌词优先，外部 `.lrc` 兜底。
    String? content;
    if (song.hasEmbeddedLyrics == 1) {
      content = await _readEmbeddedLyrics(song);
    }
    if (content == null) {
      final path = resolveLrcPath(song);
      if (path != null) {
        try {
          content = await File(path).readAsString();
        } catch (e, s) {
          AppLogger.warning('Lyric', 'Failed to read lyrics: $path', e, s);
          content = null;
        }
      }
    }

    // 竞态校验：读取期间切了歌则丢弃本次结果。
    if (_loadingForId != songId) return;

    if (content == null || content.trim().isEmpty) {
      controller.loadLyric('');
      return;
    }

    _loadLyricText(content);
    // 歌词就绪后再对齐一次位置（防御 positionStream 先发 0 的时序）。
    _syncPosition();
  }

  /// 把歌词文本加载进 flutter_lyric。
  ///
  /// - 带时间轴的（LRC/QRC）走 [splitBilingualLrc] 拆主歌词 + 翻译副行；
  /// - 纯文本（无时间轴）flutter_lyric 解析后是空行，降级为静态单行显示全文。
  void _loadLyricText(String content) {
    // 同行双语（原文 翻译）自动拆成主歌词 + 翻译两条时间轴；
    // 无翻译时 translationLyric 为空串，flutter_lyric 按无翻译处理。
    final isLrc = RegExp(r'^\[\d{1,}:\d{2}', multiLine: true).hasMatch(content);
    if (!isLrc) {
      // 纯文本降级：单行静态歌词（不跟随进度高亮/滚动，仅展示全文）。
      controller.loadLyricModel(
        LyricModel(
          lines: [LyricLine(start: Duration.zero, text: content.trim())],
        ),
      );
      return;
    }
    final split = splitBilingualLrc(content);
    controller.loadLyric(
      split.mainLyric,
      // 翻译副行：翻译开关开启 且 界面语言为中文 才显示（英文界面暂未提供
      // 英文翻译源，隐藏中文翻译副行）；否则传空串按无翻译渲染。
      translationLyric: _showTranslation && _isChineseUi()
          ? split.translationLyric
          : '',
    );
  }

  /// 读取内嵌歌词，带内存缓存 + 文件修改时间时效。
  Future<String?> _readEmbeddedLyrics(Song song) async {
    final key = song.filePath;
    // 时效判断：文件修改时间变化则缓存失效（外部工具改了标签后重读）。
    final modifiedMs = await _fileModifiedMs(song.filePath);
    final cached = _embeddedLyricsCache[key];
    if (cached != null && cached.modifiedMs == modifiedMs) {
      return cached.content.isEmpty ? null : cached.content;
    }
    final content = await _metadata.readEmbeddedLyrics(song.filePath);
    _embeddedLyricsCache[key] = (
      content: content ?? '',
      modifiedMs: modifiedMs,
    );
    return content;
  }

  Future<int> _fileModifiedMs(String path) async {
    try {
      return (await File(path).stat()).modified.millisecondsSinceEpoch;
    } catch (_) {
      return 0;
    }
  }

  void dispose() {
    _player.currentSongNotifier.removeListener(_onSongChanged);
    _positionSub?.cancel();
    controller.dispose();
  }
}
