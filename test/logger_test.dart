import 'dart:io';

import 'package:flutter_music/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempRoot;
  late Directory logDir;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('logger_test');
    logDir = Directory(p.join(tempRoot.path, 'logs'));
    AppLogger.setLogDirectory(logDir);
  });

  tearDown(() async {
    await AppLogger.dispose();
    if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
  });

  test('日志按天写入文件且格式正确', () async {
    AppLogger.info('App', 'hello world');
    await AppLogger.flushPending();

    expect(logDir.existsSync(), isTrue);
    final files = logDir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));

    final now = DateTime.now();
    final day =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    expect(p.basename(files.single.path), 'app-$day.log');

    final content = files.single.readAsStringSync();
    expect(content, contains('[INFO ]'));
    expect(content, contains('[App'));
    expect(content, contains('hello world'));
  });

  test('error 附带异常与堆栈行', () async {
    AppLogger.error(
      'Player',
      'failed to play',
      StateError('bad file'),
      StackTrace.current,
    );
    await AppLogger.flushPending();

    final file = logDir.listSync().whereType<File>().single;
    final content = file.readAsStringSync();
    expect(content, contains('[ERROR]'));
    expect(content, contains('failed to play'));
    expect(content, contains('Bad state: bad file'));
    // 堆栈首行应被记录(缩进两空格)
    expect(RegExp(r'\n  #0 ').hasMatch(content), isTrue);
  });

  test('同一天多条日志写入同一文件且级别标签定宽', () async {
    AppLogger.debug('Scan', 'start');
    AppLogger.warning('Scan', 'skip dir');
    AppLogger.fatal('Zone', 'boom', Exception('x'));
    await AppLogger.flushPending();

    final files = logDir.listSync().whereType<File>().toList();
    expect(files, hasLength(1));

    final content = files.single.readAsStringSync();
    // 级别标签均为 5 字符(右对齐填充)
    expect(RegExp(r'\[DEBUG\]').hasMatch(content), isTrue);
    expect(RegExp(r'\[WARN \]').hasMatch(content), isTrue);
    expect(RegExp(r'\[FATAL\]').hasMatch(content), isTrue);
    // tag 定宽 10 左对齐
    expect(RegExp(r'\[Scan      \]').hasMatch(content), isTrue);
  });

  test('pruneOldLogs 清理过期文件、保留近期文件', () async {
    final oldFile = File(p.join(logDir.path, 'app-2020-01-01.log'))
      ..createSync(recursive: true)
      ..writeAsStringSync('old');
    final newFile = File(p.join(logDir.path, 'app-2099-01-01.log'))
      ..createSync(recursive: true)
      ..writeAsStringSync('new');
    // 非日志文件不受影响
    final unrelated = File(p.join(logDir.path, 'readme.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('x');

    await AppLogger.pruneOldLogs(keepDays: 7);

    expect(oldFile.existsSync(), isFalse);
    expect(newFile.existsSync(), isTrue);
    expect(unrelated.existsSync(), isTrue);
  });
}
