import '../database/database.dart';
import 'settings_service.dart';

/// 简单的服务定位器，用于全局访问 Database 和 Settings。
///
/// 在 App 启动时调用 [initialize] 完成初始化。
class ServiceLocator {
  ServiceLocator._();

  static FlutterMusicDatabase? _database;
  static SettingsService? _settings;

  static FlutterMusicDatabase get database {
    if (_database == null) {
      throw StateError(
        'Database not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _database!;
  }

  static SettingsService get settings {
    if (_settings == null) {
      throw StateError(
        'Settings not initialized. Call ServiceLocator.initialize() first.',
      );
    }
    return _settings!;
  }

  static Future<void> initialize() async {
    _settings = SettingsService();
    await _settings!.initialize();
    _database = await FlutterMusicDatabase.create();
  }
}
