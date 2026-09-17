import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:watcher/watcher.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/services/folder_watcher_service.dart';
import 'package:txvziwm/core/services/song_repository.dart';

/// FolderWatcherService 去抖批量逻辑回归：不依赖真实 DirectoryWatcher 时序，
/// 直接注入内存 db + 合成事件路径（recordEvent）驱动 flushNow()。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FolderWatcherService watcher;
  late Directory dir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('folder_watcher_');
    watcher = FolderWatcherService(
      songRepository: SongRepository(database: db),
    );
  });

  tearDown(() async {
    watcher.dispose();
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<String> addFile(String name) async {
    final f = File('${dir.path}/$name');
    await f.writeAsString('fake audio');
    return f.path;
  }

  Future<void> insertAvailable(String path) async {
    await db.insertSong(
      SongsCompanion.insert(
        title: 't',
        fileName: path.split('/').last,
        filePath: path,
        dateAdded: DateTime(2024),
      ),
    );
  }

  test('批量 add/modify 一次 flush：多文件入库可用且只发一条汇总事件', () async {
    final emitted = <FolderWatcherEvent>[];
    final sub = watcher.events.listen(emitted.add);
    addTearDown(sub.cancel);

    final f1 = await addFile('one.mp3');
    final f2 = await addFile('two.mp3');
    watcher.recordEvent(f1, ChangeType.ADD);
    watcher.recordEvent(f2, ChangeType.MODIFY);

    await watcher.flushNow();

    final avail = await db.getAvailableSongs();
    expect(avail.map((s) => s.filePath).toSet(), {f1, f2});
    expect(emitted, hasLength(1), reason: '去抖批量应只发一条汇总事件');
    expect(emitted.single.addedOrUpdated, 2);
  });

  test('remove 批量标记缺失（文件确实已从磁盘消失）', () async {
    final p = await addFile('gone.mp3');
    await insertAvailable(p);
    await File(p).delete();

    watcher.recordEvent(p, ChangeType.REMOVE);
    await watcher.flushNow();

    expect(await db.getAvailableSongs(), isEmpty);
    expect((await db.getUnavailableSongs()).map((s) => s.filePath), [p]);
  });

  test('同路径 add 后 remove → 按最新 remove 处理', () async {
    final p = await addFile('x.mp3');
    await insertAvailable(p);
    await File(p).delete();

    watcher.recordEvent(p, ChangeType.ADD);
    watcher.recordEvent(p, ChangeType.REMOVE);
    await watcher.flushNow();

    expect(await db.getAvailableSongs(), isEmpty);
    expect((await db.getUnavailableSongs()).map((s) => s.filePath), [p]);
  });

  test('suspend 期间缓冲不落库，恢复后处理', () async {
    final f = await addFile('s.mp3');
    watcher.recordEvent(f, ChangeType.ADD);
    await watcher.suspend();

    await watcher.flushNow(); // suspend 中 → no-op
    expect(await db.getAvailableSongs(), isEmpty);
    expect(watcher.hasPending, isTrue);

    watcher.resume();
    await watcher.flushNow(); // resume 后排掉
    expect(watcher.hasPending, isFalse);
    expect((await db.getAvailableSongs()).map((s) => s.filePath), [f]);
  });

  test('resumeAfterScan 跳过本次扫描已处理文件的 upsert', () async {
    final f = await addFile('skip.mp3');
    watcher.recordEvent(f, ChangeType.ADD);
    await watcher.suspend();

    // 模拟：f 已被本次扫描解析过 → 跳过，不再重复入库。
    watcher.resumeAfterScan({f});

    expect(watcher.hasPending, isFalse);
    await watcher.flushNow();
    expect(await db.getAvailableSongs(), isEmpty);
  });

  test('discardPendingUnder 丢弃某文件夹下待处理事件', () async {
    final sub = await Directory.systemTemp.createTemp('folder_watcher_sub_');
    addTearDown(() async {
      if (await sub.exists()) await sub.delete(recursive: true);
    });
    final p = '${sub.path}/a.mp3';
    await File(p).writeAsString('fake');

    watcher.recordEvent(p, ChangeType.ADD);
    expect(watcher.hasPending, isTrue);
    // 取消定时器（避免散落 Timer），再验证丢弃。
    await watcher.suspend();
    watcher.discardPendingUnder(sub.path);
    expect(watcher.hasPending, isFalse);
  });

  test('文件仍在磁盘时忽略 remove（覆盖写乱序防护）', () async {
    final p = await addFile('rewrite.mp3');
    await insertAvailable(p);

    watcher.recordEvent(p, ChangeType.REMOVE); // 文件其实还在
    await watcher.flushNow();

    expect(await db.getAvailableSongs(), hasLength(1));
  });

  test('扫描期间到达的编辑不会被 resumeAfterScan 跳过', () async {
    final f = await addFile('edited.mp3');
    await watcher.suspend(); // 扫描开始
    await Future<void>.delayed(const Duration(milliseconds: 5));
    watcher.recordEvent(f, ChangeType.MODIFY); // 扫描期间到达
    watcher.resumeAfterScan({f}); // force 扫描把全部文件算作已解析

    expect(watcher.hasPending, isTrue, reason: '扫描期间的编辑必须保留');
  });
}
