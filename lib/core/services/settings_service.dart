import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/song_sort_order.dart';
import '../models/accent_color.dart';
import '../models/lyric_text_size.dart';
import '../utils/logger.dart';

/// A music folder with an optional macOS security-scoped bookmark.
///
/// The [bookmark] field stores a base64-encoded `NSData` security-scoped
/// bookmark that allows the app to access this folder across restarts.
/// It is only used on macOS with App Sandbox enabled.
class MusicFolder {
  final String path;
  final String bookmark;

  const MusicFolder({required this.path, this.bookmark = ''});

  Map<String, dynamic> toJson() => {
    'path': path,
    if (bookmark.isNotEmpty) 'bookmark': bookmark,
  };

  factory MusicFolder.fromJson(Map<String, dynamic> json) {
    return MusicFolder(
      path: json['path'] as String,
      bookmark: json['bookmark'] as String? ?? '',
    );
  }
}

class AppSettings {
  final List<MusicFolder> musicFolders;
  final String themeMode;

  /// 界面强调色（[AccentColor.name]，如 'system'/'graphite'/'deepPurple'）。
  final String accentColor;

  /// 音乐库歌曲排序方式（[SongSortOrder.name]）。
  final String songSortOrder;

  /// 启动恢复队列后是否应用上次播放位置（续播）。
  final bool resumePlaybackPosition;

  /// 播放音量（0.0~1.0）。
  final double volume;

  /// 歌词字号档位（[LyricTextSize.name]）。
  final String lyricTextSize;

  /// 歌词是否显示翻译副行。
  final bool showTranslation;

  /// 底栏是否显示「按播放进度填充」背景效果。
  final bool nowPlayingBarFill;

  /// 睡眠定时到点后是否先播完当前曲目再停止。
  ///
  /// `false`（默认）= 到点立即淡出暂停；`true` = 到点后转为"播完当前曲目再停"。
  final bool sleepTimerFinishCurrentTrack;

  const AppSettings({
    this.musicFolders = const [],
    this.themeMode = 'system',
    this.accentColor = 'graphite',
    this.songSortOrder = 'title',
    this.resumePlaybackPosition = true,
    this.volume = 1.0,
    this.lyricTextSize = 'medium',
    this.showTranslation = true,
    this.nowPlayingBarFill = true,
    this.sleepTimerFinishCurrentTrack = false,
  });

  /// The raw folder paths (convenience getter).
  List<String> get folderPaths => musicFolders.map((f) => f.path).toList();

  Map<String, dynamic> toJson() => {
    'musicFolders': musicFolders.map((f) => f.toJson()).toList(),
    'themeMode': themeMode,
    'accentColor': accentColor,
    'songSortOrder': songSortOrder,
    'resumePlaybackPosition': resumePlaybackPosition,
    'volume': volume,
    'lyricTextSize': lyricTextSize,
    'showTranslation': showTranslation,
    'nowPlayingBarFill': nowPlayingBarFill,
    'sleepTimerFinishCurrentTrack': sleepTimerFinishCurrentTrack,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final rawFolders = json['musicFolders'];
    final List<MusicFolder> folders;

    if (rawFolders is List) {
      folders = rawFolders.map((e) {
        if (e is String) {
          // Legacy format: just a path string
          return MusicFolder(path: e);
        }
        return MusicFolder.fromJson(e as Map<String, dynamic>);
      }).toList();
    } else {
      folders = [];
    }

    return AppSettings(
      musicFolders: folders,
      themeMode: json['themeMode'] as String? ?? 'system',
      accentColor: json['accentColor'] as String? ?? 'graphite',
      songSortOrder: json['songSortOrder'] as String? ?? 'title',
      resumePlaybackPosition: json['resumePlaybackPosition'] as bool? ?? true,
      volume: (json['volume'] as num?)?.toDouble() ?? 1.0,
      lyricTextSize: json['lyricTextSize'] as String? ?? 'medium',
      showTranslation: json['showTranslation'] as bool? ?? true,
      nowPlayingBarFill: json['nowPlayingBarFill'] as bool? ?? true,
      sleepTimerFinishCurrentTrack:
          json['sleepTimerFinishCurrentTrack'] as bool? ?? false,
    );
  }

  AppSettings copyWith({
    List<MusicFolder>? musicFolders,
    String? themeMode,
    String? accentColor,
    String? songSortOrder,
    bool? resumePlaybackPosition,
    double? volume,
    String? lyricTextSize,
    bool? showTranslation,
    bool? nowPlayingBarFill,
    bool? sleepTimerFinishCurrentTrack,
  }) {
    return AppSettings(
      musicFolders: musicFolders ?? this.musicFolders,
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      songSortOrder: songSortOrder ?? this.songSortOrder,
      resumePlaybackPosition:
          resumePlaybackPosition ?? this.resumePlaybackPosition,
      volume: volume ?? this.volume,
      lyricTextSize: lyricTextSize ?? this.lyricTextSize,
      showTranslation: showTranslation ?? this.showTranslation,
      nowPlayingBarFill: nowPlayingBarFill ?? this.nowPlayingBarFill,
      sleepTimerFinishCurrentTrack:
          sleepTimerFinishCurrentTrack ?? this.sleepTimerFinishCurrentTrack,
    );
  }

  AppSettings addMusicFolder(MusicFolder folder) {
    if (musicFolders.any((f) => f.path == folder.path)) return this;
    return copyWith(musicFolders: [...musicFolders, folder]);
  }

  AppSettings removeMusicFolder(String path) {
    return copyWith(
      musicFolders: musicFolders.where((f) => f.path != path).toList(),
    );
  }
}

class SettingsService {
  AppSettings _settings = const AppSettings();
  late final String _filePath;
  bool _initialized = false;

  /// 写盘串行链：并发 setter（多个 `unawaited(setXxx())`）不会互相交错覆盖，
  /// 后写者按调用顺序落盘（与 PlayQueue 的写链同思路）。
  Future<void> _saveChain = Future.value();

  AppSettings get settings => _settings;
  bool get isInitialized => _initialized;

  /// Convenience getter for raw folder paths.
  List<String> get musicFolders => _settings.folderPaths;

  /// The full list of music folders including security-scoped bookmarks.
  List<MusicFolder> get musicFolderItems => _settings.musicFolders;

  /// 音乐库歌曲排序方式。
  SongSortOrder get songSortOrder =>
      SongSortOrder.fromName(_settings.songSortOrder);

  /// 持久化排序方式到 settings.json。
  Future<void> setSongSortOrder(SongSortOrder order) async {
    _settings = _settings.copyWith(songSortOrder: order.name);
    await _save();
  }

  /// 启动恢复队列后是否应用上次播放位置（续播）。供设置界面使用。
  bool get resumePlaybackPosition => _settings.resumePlaybackPosition;

  /// 持久化续播设置。
  Future<void> setResumePlaybackPosition(bool value) async {
    _settings = _settings.copyWith(resumePlaybackPosition: value);
    await _save();
  }

  /// 睡眠定时到点后是否先播完当前曲目再停止，供设置界面使用。
  bool get sleepTimerFinishCurrentTrack =>
      _settings.sleepTimerFinishCurrentTrack;

  /// 持久化睡眠定时到点行为。
  ///
  /// 播放中的定时读的是 `SleepTimerService.waitForTrackEnd` 回调，每次都取
  /// 最新值，因此改完立即生效（无需通知播放器）。
  Future<void> setSleepTimerFinishCurrentTrack(bool value) async {
    _settings = _settings.copyWith(sleepTimerFinishCurrentTrack: value);
    await _save();
  }

  /// 播放音量（0.0~1.0）。
  double get volume => _settings.volume;

  /// 持久化音量设置。
  Future<void> setVolume(double value) async {
    _settings = _settings.copyWith(volume: value.clamp(0.0, 1.0).toDouble());
    await _save();
  }

  /// 歌词字号档位（小/中/大）。
  LyricTextSize get lyricTextSize =>
      LyricTextSize.fromName(_settings.lyricTextSize);

  /// 持久化歌词字号档位（播放页歌词菜单修改时写盘）。
  Future<void> setLyricTextSize(LyricTextSize size) async {
    _settings = _settings.copyWith(lyricTextSize: size.name);
    await _save();
  }

  /// 歌词是否显示翻译副行。
  bool get showTranslation => _settings.showTranslation;

  /// 持久化歌词翻译显示开关（播放页歌词菜单修改时写盘）。
  Future<void> setShowTranslation(bool value) async {
    _settings = _settings.copyWith(showTranslation: value);
    await _save();
  }

  /// 底栏「按播放进度填充」效果是否开启（默认开）。
  bool get nowPlayingBarFill => _settings.nowPlayingBarFill;

  /// 底栏填充开关变化通知（`NowPlayingBar._PlaybackFill` 监听，开/关即时生效）。
  final ValueNotifier<bool> nowPlayingBarFillNotifier = ValueNotifier<bool>(
    true,
  );

  /// 持久化底栏填充开关并广播变化。
  Future<void> setNowPlayingBarFill(bool value) async {
    _settings = _settings.copyWith(nowPlayingBarFill: value);
    nowPlayingBarFillNotifier.value = value;
    await _save();
  }

  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _filePath = p.join(dir.path, 'settings.json');

    final file = File(_filePath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _settings = AppSettings.fromJson(json);
      } catch (e, s) {
        // 文件损坏（例如写盘中断留下截断内容）：备份后用默认设置继续启动，
        // 避免整个应用因配置解析失败而进入启动错误页且无法自救。
        AppLogger.warning(
          'Settings',
          'settings.json unreadable; falling back to defaults',
          e,
          s,
        );
        _settings = const AppSettings();
        try {
          await file.rename('$_filePath.corrupt');
        } catch (e2) {
          AppLogger.warning(
            'Settings',
            'failed to back up corrupt settings.json',
            e2,
          );
        }
        await _save();
      }
    } else {
      _settings = const AppSettings();
      await _save();
    }

    // 同步主题模式：启动读取持久化值并通知 MaterialApp。
    themeModeNotifier.value = _themeModeFromName(_settings.themeMode);

    // 同步主题色（默认石墨灰；老配置文件缺失该键时保持默认）。
    accentColorNotifier.value = AccentColor.fromName(_settings.accentColor);

    // 同步底栏填充开关（默认开；老配置文件缺失该键时保持 true）。
    nowPlayingBarFillNotifier.value = _settings.nowPlayingBarFill;

    _initialized = true;
  }

  /// 串行、原子地持久化设置。
  ///
  /// - 串行链：并发调用不会互相交错覆盖；
  /// - temp + rename：写盘中途被杀不会留下截断的 settings.json；
  /// - 失败只记日志不向外抛：配置写失败不应让调用方崩溃。
  Future<void> _save() {
    _saveChain = _saveChain.then((_) => _writeSettingsAtomically()).catchError((
      Object e,
      StackTrace s,
    ) {
      AppLogger.warning('Settings', 'failed to persist settings.json', e, s);
    });
    return _saveChain;
  }

  Future<void> _writeSettingsAtomically() async {
    final content = const JsonEncoder.withIndent(
      '  ',
    ).convert(_settings.toJson());
    final tmp = File('$_filePath.tmp');
    await tmp.writeAsString(content, flush: true);
    final file = File(_filePath);
    // Windows 上 rename 到已存在文件会失败，需先删除；POSIX 上 rename 覆盖
    // 本身是原子的（不先删，避免「删后失败」丢配置的窗口）。
    if (Platform.isWindows && await file.exists()) {
      await file.delete();
    }
    await tmp.rename(file.path);
  }

  /// Adds a music folder with an optional security-scoped [bookmark].
  Future<void> addMusicFolder(String path, {String bookmark = ''}) async {
    _settings = _settings.addMusicFolder(
      MusicFolder(path: path, bookmark: bookmark),
    );
    await _save();
  }

  Future<void> removeMusicFolder(String path) async {
    _settings = _settings.removeMusicFolder(path);
    await _save();
  }

  /// 更新已有音乐文件夹的 security-scoped bookmark（重新授权后调用）。
  ///
  /// 与 [addMusicFolder] 不同，路径已存在时也会更新 bookmark，
  /// 用于修复失效的 macOS 沙箱权限。
  Future<void> updateMusicFolderBookmark(String path, String bookmark) async {
    _settings = _settings.copyWith(
      musicFolders: [
        for (final f in _settings.musicFolders)
          if (f.path == path)
            MusicFolder(path: f.path, bookmark: bookmark)
          else
            f,
      ],
    );
    await _save();
  }

  /// 主题模式（跟随系统/浅色/深色）。
  ///
  /// [AppSettings.themeMode] 持久化为字符串（'system'/'light'/'dark'），
  /// 这里解析成 [ThemeMode] 供 MaterialApp 使用。
  ThemeMode get themeMode => _themeModeFromName(_settings.themeMode);

  /// 主题模式变化通知：设置页切换后驱动 [MaterialApp] 重建。
  final ValueNotifier<ThemeMode> themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  /// 持久化主题模式并广播变化（触发 [MaterialApp] 切换主题）。
  Future<void> setThemeMode(ThemeMode mode) async {
    _settings = _settings.copyWith(themeMode: mode.name);
    themeModeNotifier.value = mode;
    await _save();
  }

  /// 界面强调色（预设色板 / 跟随系统）。
  ///
  /// [AppSettings.accentColor] 持久化为字符串（[AccentColor.name]），
  /// 这里解析成 [AccentColor] 供 MaterialApp 决定 seed。
  AccentColor get accentColor => AccentColor.fromName(_settings.accentColor);

  /// 主题色变化通知：设置页切换后驱动 [MaterialApp] 重建换肤。
  final ValueNotifier<AccentColor> accentColorNotifier =
      ValueNotifier<AccentColor>(AccentColor.graphite);

  /// 持久化主题色并广播变化（触发 [MaterialApp] 换肤）。
  Future<void> setAccentColor(AccentColor color) async {
    _settings = _settings.copyWith(accentColor: color.name);
    accentColorNotifier.value = color;
    await _save();
  }

  static ThemeMode _themeModeFromName(String name) {
    switch (name) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
