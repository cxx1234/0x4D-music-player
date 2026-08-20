import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/settings_service.dart';

void main() {
  group('AppSettings.volume', () {
    test('默认音量为 1.0', () {
      expect(const AppSettings().volume, 1.0);
    });

    test('toJson/fromJson 往返保留音量', () {
      const settings = AppSettings(volume: 0.4);
      final restored = AppSettings.fromJson(settings.toJson());
      expect(restored.volume, 0.4);
    });

    test('旧 JSON 无 volume 时回退 1.0（向后兼容）', () {
      expect(AppSettings.fromJson(const {}).volume, 1.0);
    });

    test('fromJson 读取音量（数值类型兼容）', () {
      expect(AppSettings.fromJson(const {'volume': 0.6}).volume, 0.6);
      expect(AppSettings.fromJson(const {'volume': 0}).volume, 0.0);
    });
  });
}
