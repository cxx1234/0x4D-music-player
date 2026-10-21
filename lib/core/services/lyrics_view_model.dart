import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';
import 'metadata_service.dart';
import 'player_lyric_progress_source.dart';
import 'player_service.dart';
import '../utils/bilingual_lrc.dart';
import '../utils/logger.dart';

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

/// 把歌词文本解析成 [LyricDocument]。
///
/// - LRC：先经 [splitBilingualLrc] 拆出主歌词 + 翻译两条时间轴；
///   [includeTranslation] 只决定是否带上副行。
/// - QRC / YRC 等词级时间轴：交给 flutter_lyric 自动探测，避免被误当成
///   纯文本压成一行静态歌词。
/// - 完全无时间轴：降级为单行静态歌词。
///
/// [hasTranslation] 是内容事实，与翻译开关/界面语言无关。
({LyricDocument document, bool hasTranslation}) parseLyricContent(
  String content, {
  bool includeTranslation = true,
}) {
  final isLrc = RegExp(r'^\[\d{1,}:\d{2}', multiLine: true).hasMatch(content);
  if (isLrc) {
    final split = splitBilingualLrc(content);
    final hasTranslation = split.translationLyric.isNotEmpty;
    return (
      document: LyricDocument.parse(
        split.mainLyric,
        translation: includeTranslation && hasTranslation
            ? split.translationLyric
            : null,
      ),
      hasTranslation: hasTranslation,
    );
  }

  final timed = LyricDocument.parse(content);
  if (timed.lines.isNotEmpty) {
    return (document: timed, hasTranslation: false);
  }

  return (
    document: LyricDocument(
      lines: [LyricLine(start: Duration.zero, text: content.trim())],
    ),
    hasTranslation: false,
  );
}

/// 歌词视图模型：驱动 flutter_lyric 的 [LyricController]。
///
/// - 监听当前歌曲变化（[PlayerService.currentSongNotifier]，按歌曲去重）→
///   读取 `.lrc` → [LyricController.loadDocument]；
/// - 通过 [PlayerLyricProgressSource] 把播放进度交给控制器逐帧采样，
///   驱动歌词高亮与滚动（不再手动调用 [LyricController.setPosition]）。
///
/// 歌词路径解析：[Song.lyricsFilePath]（数据库扫描时记录）优先；不存在时
/// 实时按音频文件找同名 `.lrc`/`.LRC` 兜底，因此新放的歌词文件无需重新扫描。
///
/// 自 2026-09-03 起为 [ServiceLocator] 注册的**常驻服务**，与 [PlayerService]
/// 同生命周期（不再随播放页 pop 销毁）——播放页关闭再打开不会重新读盘/解析歌词；
/// 播放页之外切歌也能持续跟踪。播放页只消费 [controller]/[hasTranslationNotifier]。
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
    bool initialShowTranslation = true,
  }) : _player = player,
       _isChineseUi = isChineseUi ?? _defaultIsChineseUi,
       _metadata = metadataService ?? MetadataService() {
    // 翻译副行初值（常驻服务场景：ServiceLocator 用持久化设置传入；
    // 页面级新实例场景保持默认 true）。须在首次 _onSongChanged() 前生效。
    _showTranslation = initialShowTranslation;
    // 高亮/滚动提前一点切换（跟唱更顺）。
    controller.timeOffset = const Duration(milliseconds: _kLyricOffsetMs);
    _player.currentSongNotifier.addListener(_onSongChanged);
    // 控制器接管进度订阅：绑定后由它按可见性逐帧采样，不能再手动 setPosition。
    _progressSource = PlayerLyricProgressSource(_player);
    controller.progressSource = _progressSource;
    // 初始加载当前歌曲（若打开播放页前已有歌在播）。绑定 source 时会立即
    // 采样一次当前位置，续播/暂停状态无需额外同步。
    _onSongChanged();
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

  late final PlayerLyricProgressSource _progressSource;

  /// 正在加载歌词的歌曲 id（防快速切歌时过期结果覆盖新歌）。
  int? _loadingForId;

  /// 是否显示翻译副行（由歌词菜单栏开关控制）。
  bool _showTranslation = true;

  /// 当前歌词是否含翻译副行（内容事实，与用户翻译开关/界面语言无关）。
  /// 无歌词、纯文本降级、或拆分后无翻译时均为 false；UI 据此禁用翻译开关。
  final ValueNotifier<bool> hasTranslationNotifier = ValueNotifier(false);

  /// 切换翻译副行显隐（重新加载当前歌词）。
  void setShowTranslation(bool show) {
    if (show == _showTranslation) return;
    _showTranslation = show;
    _loadForSong(_player.currentSong);
  }

  void _onSongChanged() {
    _loadForSong(_player.currentSong);
  }

  Future<void> _loadForSong(Song? song) async {
    final songId = song?.id;
    _loadingForId = songId;

    if (song == null) {
      // 无歌词：清空上次歌词（LyricView 据此显示"暂无歌词"占位）。
      hasTranslationNotifier.value = false;
      controller.clear();
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
      hasTranslationNotifier.value = false;
      controller.clear();
      return;
    }

    _loadLyricText(content);
  }

  /// 把歌词文本加载进 flutter_lyric。
  void _loadLyricText(String content) {
    final parsed = parseLyricContent(
      content,
      // 翻译副行：翻译开关开启 且 界面语言为中文才显示（英文界面暂未提供
      // 英文翻译源，隐藏中文翻译副行）。
      includeTranslation: _showTranslation && _isChineseUi(),
    );
    hasTranslationNotifier.value = parsed.hasTranslation;
    controller.loadDocument(parsed.document);
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
    _progressSource.dispose();
    controller.dispose();
    hasTranslationNotifier.dispose();
  }
}
