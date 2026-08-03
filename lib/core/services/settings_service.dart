import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/song_sort_order.dart';

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

  /// 音乐库歌曲排序方式（[SongSortOrder.name]）。
  final String songSortOrder;

  const AppSettings({
    this.musicFolders = const [],
    this.themeMode = 'system',
    this.songSortOrder = 'title',
  });

  /// The raw folder paths (convenience getter).
  List<String> get folderPaths => musicFolders.map((f) => f.path).toList();

  Map<String, dynamic> toJson() => {
    'musicFolders': musicFolders.map((f) => f.toJson()).toList(),
    'themeMode': themeMode,
    'songSortOrder': songSortOrder,
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
      songSortOrder: json['songSortOrder'] as String? ?? 'title',
    );
  }

  AppSettings copyWith({
    List<MusicFolder>? musicFolders,
    String? themeMode,
    String? songSortOrder,
  }) {
    return AppSettings(
      musicFolders: musicFolders ?? this.musicFolders,
      themeMode: themeMode ?? this.themeMode,
      songSortOrder: songSortOrder ?? this.songSortOrder,
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

  Future<void> initialize() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _filePath = p.join(dir.path, 'settings.json');

    final file = File(_filePath);
    if (await file.exists()) {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      _settings = AppSettings.fromJson(json);
    } else {
      _settings = const AppSettings();
      await _save();
    }

    _initialized = true;
  }

  Future<void> _save() async {
    final file = File(_filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(_settings.toJson()),
    );
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

  Future<void> setThemeMode(String mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _save();
  }
}
