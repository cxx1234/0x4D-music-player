import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/settings_service.dart';

/// 回归：settings.json 写盘必须是「串行 + 原子」的，且损坏时不能卡住启动。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('settings_persist_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return dir.path;
          }
          return null;
        });
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('损坏的 settings.json → 回退默认、备份 .corrupt、重写可用配置', () async {
    final file = File('${dir.path}/settings.json');
    await file.writeAsString('{"musicFolders": [  <<< truncated');

    final settings = SettingsService();
    await settings.initialize(); // 不应抛异常

    expect(settings.volume, 1.0); // 默认值
    expect(await File('${dir.path}/settings.json.corrupt').exists(), isTrue);
    final rewritten =
        jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(rewritten['volume'], 1.0);
  });

  test('并发 setter 串行写盘：最终文件为合法 JSON 且包含全部修改', () async {
    final settings = SettingsService();
    await settings.initialize();

    await Future.wait([
      settings.setVolume(0.3),
      settings.setResumePlaybackPosition(false),
      settings.setNowPlayingBarFill(false),
      settings.setShowTrackChangeNotification(false),
    ]);

    final file = File('${dir.path}/settings.json');
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    expect(json['volume'], 0.3);
    expect(json['resumePlaybackPosition'], false);
    expect(json['nowPlayingBarFill'], false);
    expect(json['showTrackChangeNotification'], false);
    // 原子写不留下临时文件
    expect(await File('${dir.path}/settings.json.tmp').exists(), isFalse);
  });
}
