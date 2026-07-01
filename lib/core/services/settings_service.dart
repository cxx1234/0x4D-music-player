import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppSettings {
  final List<String> musicFolders;
  final String themeMode;

  const AppSettings({this.musicFolders = const [], this.themeMode = 'system'});

  Map<String, dynamic> toJson() => {
    'musicFolders': musicFolders,
    'themeMode': themeMode,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      musicFolders: List<String>.from(json['musicFolders'] ?? []),
      themeMode: json['themeMode'] as String? ?? 'system',
    );
  }

  AppSettings copyWith({List<String>? musicFolders, String? themeMode}) {
    return AppSettings(
      musicFolders: musicFolders ?? this.musicFolders,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  AppSettings addMusicFolder(String path) {
    if (musicFolders.contains(path)) return this;
    return copyWith(musicFolders: [...musicFolders, path]);
  }

  AppSettings removeMusicFolder(String path) {
    return copyWith(
      musicFolders: musicFolders.where((f) => f != path).toList(),
    );
  }
}

class SettingsService {
  AppSettings _settings = const AppSettings();
  late final String _filePath;
  bool _initialized = false;

  AppSettings get settings => _settings;
  bool get isInitialized => _initialized;

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

  Future<void> addMusicFolder(String path) async {
    _settings = _settings.addMusicFolder(path);
    await _save();
  }

  Future<void> removeMusicFolder(String path) async {
    _settings = _settings.removeMusicFolder(path);
    await _save();
  }

  List<String> get musicFolders => _settings.musicFolders;

  Future<void> setThemeMode(String mode) async {
    _settings = _settings.copyWith(themeMode: mode);
    await _save();
  }
}
