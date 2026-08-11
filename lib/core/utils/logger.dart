import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 日志级别,按严重度升序。
enum AppLogLevel {
  debug('DEBUG'),
  info('INFO'),
  warning('WARN'),
  error('ERROR'),
  fatal('FATAL');

  const AppLogLevel(this.label);

  /// 5 字符定宽标签(右对齐填充),便于 grep/对齐。
  final String label;
}

/// 统一的分级日志出口。
///
/// 所有日志同时输出到:
/// 1. `debugPrint`(开发期控制台,保留原有调试体验);
/// 2. `{appDocDir}/logs/app-YYYY-MM-DD.log`(按天分文件,启动时清理旧文件)。
///
/// 约定:消息用英文(与堆栈/框架日志统一);tag 用分类名
/// (App/Startup/Player/Scan/Sandbox/DB/Cache/M3U/Settings/FolderWatch/Zone/Flutter/Platform)。
///
/// 日志系统自身失败绝不抛异常(否则会递归崩溃),一律降级为 `debugPrint`。
abstract final class AppLogger {
  /// 单文件大小防御上限(超过则截断)。一天正常日志远小于该值。
  static const int _maxFileBytes = 5 * 1024 * 1024;

  static Directory? _logDir;
  static IOSink? _sink;
  static String? _sinkDay;

  /// 写文件队列链:保证同一文件被串行追加,避免并发交错。
  static Future<void> _pending = Future.value();

  static void debug(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _log(AppLogLevel.debug, tag, message, error, stack);

  static void info(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _log(AppLogLevel.info, tag, message, error, stack);

  static void warning(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _log(AppLogLevel.warning, tag, message, error, stack);

  static void error(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _log(AppLogLevel.error, tag, message, error, stack);

  static void fatal(
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) => _log(AppLogLevel.fatal, tag, message, error, stack);

  /// 覆盖日志根目录(仅测试使用)。传入后日志写到 `{dir}/logs/`。
  @visibleForTesting
  static void setLogDirectory(Directory dir) {
    _logDir = dir;
  }

  /// 日志根目录(供日志查看页读取日志文件)。
  static Future<Directory> logDirectory() => _resolveLogDir();

  /// 等待所有已排队的日志写入落盘(仅测试使用)。
  @visibleForTesting
  static Future<void> flushPending() => _pending;

  /// 关闭底层文件句柄,等待所有待写日志落盘(仅测试使用)。
  @visibleForTesting
  static Future<void> dispose() async {
    await _pending;
    if (_sink != null) {
      await _sink!.flush();
      await _sink!.close();
      _sink = null;
      _sinkDay = null;
    }
  }

  /// 删除 [keepDays] 天前的日志文件。默认保留最近 7 天。
  ///
  /// 建议在应用启动时调用一次;清理失败不抛异常,仅记录。
  static Future<void> pruneOldLogs({int keepDays = 7}) async {
    try {
      final dir = await _resolveLogDir();
      if (!await dir.exists()) return;
      final cutoff = DateTime.now().subtract(Duration(days: keepDays));
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (!name.startsWith('app-') || !name.endsWith('.log')) continue;
        final day = DateTime.tryParse(name.substring(4, name.length - 4));
        if (day != null && day.isBefore(cutoff)) {
          await entity.delete();
          debugPrint('[AppLogger] pruned $name');
        }
      }
    } catch (e) {
      debugPrint('[AppLogger] pruneOldLogs failed: $e');
    }
  }

  // ─── 内部实现 ────────────────────────────────────────

  static void _log(
    AppLogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stack,
  ]) {
    final now = DateTime.now();
    final line = _format(now, level, tag, message);
    debugPrint(line);
    if (error != null) debugPrint('  $error');
    if (stack != null) debugPrint('  $stack');

    // 串行排队写盘(不阻塞调用方)。
    _pending = _pending.then((_) => _append(now, line, error, stack));
  }

  static String _format(
    DateTime now,
    AppLogLevel level,
    String tag,
    String message,
  ) {
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    final ts =
        '${now.year}-${two(now.month)}-${two(now.day)} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}.${three(now.millisecond)}';
    final levelTag = level.label.padRight(5);
    final tagTag = tag.padRight(10);
    return '$ts [$levelTag] [$tagTag] $message';
  }

  static Future<void> _append(
    DateTime now,
    String line,
    Object? error,
    StackTrace? stack,
  ) async {
    try {
      final day = _dayKey(now);
      if (_sink == null || _sinkDay != day) {
        if (_sink != null) {
          await _sink!.flush();
          await _sink!.close();
          _sink = null;
          _sinkDay = null;
        }
        final dir = await _resolveLogDir();
        await dir.create(recursive: true);
        final file = File(p.join(dir.path, 'app-$day.log'));
        // 防御上限:超限截断,避免异常风暴把磁盘写爆。
        if (await file.exists() && await file.length() > _maxFileBytes) {
          await file.writeAsString('', flush: true);
          debugPrint(
            '[AppLogger] truncated app-$day.log (over ${_maxFileBytes ~/ (1024 * 1024)}MB)',
          );
        }
        _sink = file.openWrite(mode: FileMode.append);
        _sinkDay = day;
      }
      _sink!.writeln(line);
      if (error != null) _sink!.writeln('  $error');
      if (stack != null) _sink!.writeln('  $stack');
      await _sink!.flush();
    } catch (e) {
      // 日志写入失败绝不能向外抛,否则日志系统自身会递归崩溃。
      debugPrint('[AppLogger] write failed: $e');
    }
  }

  static Future<Directory> _resolveLogDir() async {
    if (_logDir != null) return _logDir!;
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(p.join(appDir.path, 'logs'));
  }

  static String _dayKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}
