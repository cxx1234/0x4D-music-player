import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/album_art_cache_service.dart';

/// 回归测试：docs/Performance-Optimization.md 5.2
/// 「getAlbumArtPath 恒返回 .jpg，但 saveAlbumArt 按 mime 存 png/webp/gif → 潜在读取不到」。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const _channel = MethodChannel('plugins.flutter.io/path_provider');
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('art_cache_ext_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory')
            return temp.path;
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  // 只取文件头几个 magic 字节即可；本测试只关心扩展名逻辑，不关心图像合法性。
  final pngHeader = Uint8List.fromList([
    0x89,
    0x50,
    0x4e,
    0x47,
    0x0d,
    0x0a,
    0x1a,
    0x0a,
  ]);
  final jpegHeader = Uint8List.fromList([0xff, 0xd8, 0xff, 0xe0]);
  const albumKey = 'Album::Artist';

  group('AlbumArtCacheService 扩展名一致性（docs 5.2）', () {
    test('保存 PNG 后 getAlbumArtPath/hasAlbumArt 命中真实 .png 而非 .jpg', () async {
      final cache = AlbumArtCacheService();

      final saved = await cache.saveAlbumArt(albumKey, pngHeader, 'image/png');
      expect(saved.endsWith('.png'), isTrue);

      final lookedUp = await cache.getAlbumArtPath(albumKey);
      expect(lookedUp, saved, reason: '读取必须返回真实扩展名，不能恒 .jpg');
      expect(await cache.hasAlbumArt(albumKey), isTrue);
      expect(File(lookedUp).existsSync(), isTrue);
    });

    test('保存 PNG 时清除同 hash 的旧 .jpg 残留，避免探测命中过期文件', () async {
      final cache = AlbumArtCacheService();

      await cache.saveAlbumArt(albumKey, jpegHeader, 'image/jpeg'); // 先写 .jpg
      final afterPng = await cache.saveAlbumArt(
        albumKey,
        pngHeader,
        'image/png',
      );

      expect(afterPng.endsWith('.png'), isTrue);
      final lookedUp = await cache.getAlbumArtPath(albumKey);
      expect(lookedUp, afterPng, reason: '旧 .jpg 残留应被清理');

      // 本测试只写过一个 key，covers 目录里应只剩一个文件且为 .png。
      final coversDir = await cache.cacheDir;
      final files = coversDir.listSync().whereType<File>().toList();
      expect(files, hasLength(1));
      expect(files.single.path, afterPng);
    });
  });
}
