import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/library_scanner_service.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('scan_detect_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<String> touchFile(String name, {String content = 'x'}) async {
    final f = File('${dir.path}/$name');
    await f.writeAsString(content);
    return f.path;
  }

  ({int? lastModifiedMs, int? fileSize}) stampOf(String path) {
    final s = FileStat.statSync(path);
    return (
      lastModifiedMs: s.modified.millisecondsSinceEpoch,
      fileSize: s.size,
    );
  }

  test('未变化的文件不返回', () async {
    final p = await touchFile('a.mp3');
    final result = detectChangedFiles([p], {p: stampOf(p)});
    expect(result, isEmpty);
  });

  test('mtime 变化 → 视为变化', () async {
    final p = await touchFile('a.mp3');
    final s = stampOf(p);
    final stale = (
      lastModifiedMs: s.lastModifiedMs! - 1000,
      fileSize: s.fileSize,
    );
    final result = detectChangedFiles([p], {p: stale});
    expect(result, [p]);
  });

  test('size 变化 → 视为变化', () async {
    final p = await touchFile('a.mp3', content: 'x');
    final stale = stampOf(p);
    await File(p).writeAsString('much longer content');
    final result = detectChangedFiles([p], {p: stale});
    expect(result, [p]);
  });

  test('stamp 缺失（旧数据无时间戳）→ 视为变化', () async {
    final p = await touchFile('a.mp3');
    final result = detectChangedFiles([p], {});
    expect(result, [p]);
  });

  test('stat 失败（文件不存在）→ 视为变化', () async {
    final missing = '${dir.path}/missing.mp3';
    final result = detectChangedFiles([missing], {});
    expect(result, [missing]);
  });
}
