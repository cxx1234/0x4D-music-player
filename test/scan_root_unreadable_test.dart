import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/library_scanner_service.dart';
import 'package:txvziwm/core/services/song_repository.dart';
import 'package:txvziwm/models/scanned_song.dart';

/// 回归：某个扫描根读取失败（外接盘未挂载/权限异常）时，该根在库内的歌曲
/// 不得被误标为不可用——否则整根从 UI 消失，并会被 pruneQueue 移出播放队列。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SongRepository repo;
  late Directory docs;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = SongRepository(database: db);
    docs = await Directory.systemTemp.createTemp('scan_root_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getApplicationDocumentsDirectory') {
            return docs.path;
          }
          return null;
        });
  });

  tearDown(() async {
    await db.close();
    if (await docs.exists()) await docs.delete(recursive: true);
  });

  test('根不可读时该根歌曲保持可用（不误标 missing）', () async {
    final unreadableRoot = '${docs.path}/not-mounted';
    await repo.insertOrUpdateFromScan([
      ScannedSong(
        filePath: '$unreadableRoot/song.mp3',
        fileName: 'song.mp3',
        fileSize: 1000,
        title: 'Song',
        mimeType: 'audio/mpeg',
      ),
    ]);

    final scanner = LibraryScannerService(songRepository: repo);
    await scanner.scanFolders([unreadableRoot], markMissing: true);

    final songs = await db.getAllSongs();
    expect(songs, hasLength(1));
    expect(songs.single.isAvailable, 1, reason: '不可读的根不应导致误标缺失');
  });
}
