import 'package:txvziwm/features/settings/log_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('解析单行日志：时间/级别/tag/消息', () {
    final entries = parseLogLines([
      '2026-08-11 10:23:45.123 [INFO ] [App    ] MetadataGod initialized successfully',
    ]);
    expect(entries, hasLength(1));
    final e = entries.single;
    expect(e.timestamp, DateTime(2026, 8, 11, 10, 23, 45, 123));
    expect(e.level, 'INFO');
    expect(e.tag, 'App');
    expect(e.message, 'MetadataGod initialized successfully');
    expect(e.detailLines, isEmpty);
  });

  test('附加行（异常/堆栈）归属上一条', () {
    final entries = parseLogLines([
      '2026-08-11 10:23:46.001 [ERROR] [Player ] failed to play',
      '  PlayerException: boom',
      '  #0      main (file.dart:1)',
      '2026-08-11 10:23:47.000 [WARN ] [Scan   ] skip dir',
    ]);
    expect(entries, hasLength(2));
    expect(entries[0].message, 'failed to play');
    expect(entries[0].detailLines, [
      '  PlayerException: boom',
      '  #0      main (file.dart:1)',
    ]);
    expect(entries[1].message, 'skip dir');
    expect(entries[1].detailLines, isEmpty);
  });

  test('空行与非日志文本处理', () {
    final entries = parseLogLines([
      '',
      '   ',
      'some random line without timestamp',
      '2026-08-11 10:00:00.000 [INFO] [App] hello',
      '',
    ]);
    expect(entries, hasLength(1));
    // 无当前条目时的游离行被忽略
    expect(entries.single.message, 'hello');
    expect(entries.single.detailLines, isEmpty);
  });
}
