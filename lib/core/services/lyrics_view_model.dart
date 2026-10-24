import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_lyric/flutter_lyric.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';
import '../models/lyric_load_state.dart';
import '../utils/lyric_document_parser.dart';
import '../utils/logger.dart';
import 'metadata_service.dart';
import 'player_lyric_progress_source.dart';
import 'player_service.dart';

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
class LyricsViewModel with WidgetsBindingObserver {
  /// 高亮/滚动切换到下一行的提前量（毫秒）：正值让歌词高亮比实际时间戳
  /// 早一点切换，跟唱更顺；不影响点击歌词 seek（其回调用原始时间戳）。
  static const int _kLyricOffsetMs = 300;

  /// 默认判定：平台 locale 是否为中文。
  static bool _defaultIsChineseUi() {
    final lang = WidgetsBinding.instance.platformDispatcher.locale.languageCode
        .toLowerCase();
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
    WidgetsBinding.instance.addObserver(this);
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

  /// 异步加载代际：每次切歌 / 翻译重载自增，过期结果直接丢弃。
  int _loadGeneration = 0;

  /// 当前歌曲已经读到的原始歌词；翻译开关直接重解析，避免再次读盘。
  String? _currentContent;

  /// 当前 controller 中的文档属于哪首歌。用于 resume 时对账：后台期间若
  /// 漏掉了 currentSongNotifier（或加载被挂起），回到前台要强制重新加载。
  int? _documentSongId;
  String? _documentFilePath;

  /// 是否显示翻译副行（由歌词菜单栏开关控制）。
  bool _showTranslation = true;

  /// 当前歌词是否含翻译副行（内容事实，与用户翻译开关/界面语言无关）。
  /// 无歌词、纯文本降级、或拆分后无翻译时均为 false；UI 据此禁用翻译开关。
  final ValueNotifier<bool> hasTranslationNotifier = ValueNotifier(false);

  /// 当前曲目的歌词加载状态（切歌时先进入 loading，避免旧歌词继续显示）。
  final ValueNotifier<LyricLoadState> loadStateNotifier =
      ValueNotifier<LyricLoadState>(LyricLoadState.idle);

  /// 是否已经跟踪过一首歌。首次加载（启动恢复队列）没有旧歌词需要保护，
  /// 不应等待引擎加载，否则恢复队列未播放时会一直停在 loading。
  bool _hasSeenSong = false;

  /// 切换翻译副行显隐（重新解析当前歌词，保留当前播放位置）。
  void setShowTranslation(bool show) {
    if (show == _showTranslation) return;
    _showTranslation = show;
    _loadForSong(_player.currentSong, trackChanged: false);
  }

  /// 界面语言变化后重新解析当前歌词。
  ///
  /// 翻译副行只在中文界面显示；语言切换时必须重解析，否则会继续沿用切换前
  /// 的文档（详见 [_loadLyricText]）。
  void refreshLocaleDependentContent() {
    if (_currentContent == null) return;
    _loadForSong(_player.currentSong, trackChanged: false, waitForTrack: false);
  }

  void _onSongChanged() {
    final song = _player.currentSong;
    final waitForTrack = _hasSeenSong && song != null;
    _hasSeenSong = song != null;
    _loadForSong(song, waitForTrack: waitForTrack);
  }

  Future<void> _loadForSong(
    Song? song, {
    bool trackChanged = true,
    bool waitForTrack = true,
  }) async {
    final generation = ++_loadGeneration;

    if (trackChanged) {
      _currentContent = null;
      _documentSongId = null;
      _documentFilePath = null;
      // 切歌瞬间摘掉旧文档和进度源：旧歌词不能继续挂在新歌标题下，
      // 也不能在加载窗口里被旧位置重新定位。
      controller.progressSource = null;
      controller.clear();
      hasTranslationNotifier.value = false;
      loadStateNotifier.value = song == null
          ? LyricLoadState.idle
          : LyricLoadState.loading;
    }

    if (song == null) {
      _documentSongId = null;
      _documentFilePath = null;
      if (!trackChanged) loadStateNotifier.value = LyricLoadState.empty;
      return;
    }

    // 歌词来源优先级：内嵌歌词优先，外部 `.lrc` 兜底。
    var content = !trackChanged ? _currentContent : null;
    if (content == null) {
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
    }

    // 读取期间切歌 / 重载了翻译：丢弃过期结果。
    if (generation != _loadGeneration || !_isCurrent(song)) return;

    _currentContent = content;
    _documentSongId = song.id;
    _documentFilePath = song.filePath;

    if (content == null || content.trim().isEmpty) {
      hasTranslationNotifier.value = false;
      controller.clear();
      loadStateNotifier.value = LyricLoadState.empty;
      return;
    }

    // 切歌后必须等播放器真正加载好新曲，再让 source 同步采样一次位置；
    // 否则 loadDocument 会沿用上一首的最后位置，先渲染到旧时间点再跳回开头。
    // 翻译开关重载时 source 通常已经挂着，不需要等待，也不会重置位置。
    final needsSource = trackChanged || controller.progressSource == null;
    if (needsSource) {
      if (waitForTrack) {
        final ready = await _waitForTrackLoaded(song, generation);
        if (generation != _loadGeneration || !_isCurrent(song)) return;
        if (!ready) {
          // 音频加载失败/超时仍挂上歌词，但位置来自当前播放器（通常已归零）；
          // 不能因为音频问题把歌词永久卡在 loading。
          AppLogger.warning(
            'Lyric',
            'Track did not report loaded before lyrics: ${song.filePath}',
          );
        }
      }
      controller.progressSource = _progressSource;
    }

    _loadLyricText(content);
    loadStateNotifier.value = LyricLoadState.ready;
  }

  /// App 回到前台时对账：后台期间可能漏掉切歌通知，或加载停在半路。
  ///
  /// 正常情况下 currentSongNotifier 已经处理过；这里是兜底，不改变前台行为。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reconcileWithPlayer();
  }

  void _reconcileWithPlayer() {
    final song = _player.currentSong;
    if (song == null) {
      if (controller.document != null || _documentSongId != null) {
        _loadForSong(null);
      }
      return;
    }

    final sameSong =
        _documentSongId == song.id && _documentFilePath == song.filePath;
    if (!sameSong ||
        (loadStateNotifier.value == LyricLoadState.loading &&
            controller.document == null)) {
      AppLogger.info(
        'Lyric',
        'Resume reconcile: reloading song ${song.id} '
            '(document was ${_documentSongId ?? 'none'})',
      );
      _loadForSong(song);
      return;
    }

    if (controller.document != null && controller.progressSource == null) {
      AppLogger.info(
        'Lyric',
        'Resume reconcile: reattached progress source for song ${song.id}',
      );
      controller.progressSource = _progressSource;
      loadStateNotifier.value = LyricLoadState.ready;
    }
  }

  bool _isCurrent(Song song) {
    final current = _player.currentSong;
    return current != null &&
        current.id == song.id &&
        current.filePath == song.filePath;
  }

  Future<bool> _waitForTrackLoaded(Song song, int generation) async {
    if (_player.loadedSongNotifier.value?.id == song.id) return true;

    final completer = Completer<bool>();
    void listener() {
      if (generation != _loadGeneration) {
        _player.loadedSongNotifier.removeListener(listener);
        if (!completer.isCompleted) completer.complete(false);
        return;
      }
      if (_player.loadedSongNotifier.value?.id == song.id) {
        _player.loadedSongNotifier.removeListener(listener);
        if (!completer.isCompleted) completer.complete(true);
      }
    }

    _player.loadedSongNotifier.addListener(listener);
    // 注册后立即复查，避免在初次检查与监听之间刚好完成加载。
    listener();
    try {
      return await completer.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      _player.loadedSongNotifier.removeListener(listener);
      return false;
    }
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
    WidgetsBinding.instance.removeObserver(this);
    _player.currentSongNotifier.removeListener(_onSongChanged);
    _progressSource.dispose();
    controller.dispose();
    hasTranslationNotifier.dispose();
    loadStateNotifier.dispose();
  }
}
