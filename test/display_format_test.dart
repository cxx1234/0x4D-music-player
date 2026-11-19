import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/utils/display_format.dart';

void main() {
  group('formatFileSize', () {
    test('按 B / KB / MB / GB 分档', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(1023), '1023 B');
      expect(formatFileSize(1024), '1 KB');
      expect(formatFileSize(1536), '2 KB');
      expect(formatFileSize(10 * 1024 * 1024 + 512 * 1024), '10.5 MB');
      expect(formatFileSize(1536 * 1024 * 1024), '1.50 GB');
    });
  });

  group('formatDurationMs', () {
    test('分:秒，秒不足两位补零', () {
      expect(formatDurationMs(0), '0:00');
      expect(formatDurationMs(268000), '4:28');
      expect(formatDurationMs(3599000), '59:59');
    });

    test('秒数四舍五入会进位（59.6s → 1:00 而不是 0:60）', () {
      expect(formatDurationMs(59600), '1:00');
    });

    test('超过一小时带小时段', () {
      expect(formatDurationMs(3600000), '1:00:00');
      expect(formatDurationMs(3661000), '1:01:01');
    });

    test('空值或负数返回 null', () {
      expect(formatDurationMs(null), isNull);
      expect(formatDurationMs(-1), isNull);
    });
  });

  group('formatBitrate', () {
    test('kbps 与 Mbps 分档', () {
      expect(formatBitrate(320000), '320 kbps');
      expect(formatBitrate(1000000), '1.00 Mbps');
      expect(formatBitrate(1044077), '1.04 Mbps');
      expect(formatBitrate(3196995), '3.20 Mbps');
    });

    test('空值或非正数返回 null', () {
      expect(formatBitrate(null), isNull);
      expect(formatBitrate(0), isNull);
    });
  });

  group('formatSampleRate', () {
    test('整数 kHz 不带小数，非整数保留一位', () {
      expect(formatSampleRate(8000), '8 kHz');
      expect(formatSampleRate(48000), '48 kHz');
      expect(formatSampleRate(96000), '96 kHz');
      expect(formatSampleRate(44100), '44.1 kHz');
      expect(formatSampleRate(88200), '88.2 kHz');
    });

    test('空值或非正数返回 null', () {
      expect(formatSampleRate(null), isNull);
      expect(formatSampleRate(0), isNull);
    });
  });

  group('averageBitrateBps', () {
    test('用文件大小 ÷ 时长，忽略解析器给的位率', () {
      // 真实样本：16-bit / 44.1 kHz FLAC，解析器返回 705600（PCM 位率），
      // 实际平均码率 ≈ 1044077。
      final value = averageBitrateBps(
        fileSize: 36544379,
        durationMs: 280013,
        fallbackBps: 705600,
      );
      expect(value, 1044077);
    });

    test('算不出平均码率时才回退解析值', () {
      expect(
        averageBitrateBps(fileSize: 1000, durationMs: 0, fallbackBps: 320000),
        320000,
      );
      expect(
        averageBitrateBps(
          fileSize: null,
          durationMs: 1000,
          fallbackBps: 320000,
        ),
        320000,
      );
      expect(averageBitrateBps(fileSize: 1000, durationMs: 1000), 8000);
      expect(averageBitrateBps(fallbackBps: 0), isNull);
      expect(averageBitrateBps(), isNull);
    });
  });
}
