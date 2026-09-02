import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/utils/logger.dart';

Future<void> main() async {
  // 启动时清理 7 天前的日志文件(不阻塞启动)。
  unawaited(AppLogger.pruneOldLogs());

  runZonedGuarded(
    () {
      // 必须在 runZonedGuarded 内初始化 binding,使其与 runApp 处于同一 zone,
      // 否则会触发 "bindings initialized in a different zone" 告警。
      WidgetsFlutterBinding.ensureInitialized();

      // 全局 Flutter 错误:记录 fatal 日志;debug 下保留默认红屏便于开发,
      // release 下不再红屏(由 ErrorWidget.builder 接管)。
      FlutterError.onError = (details) {
        AppLogger.fatal('Flutter', details.exceptionAsString(), details.stack);
        if (kDebugMode) {
          FlutterError.presentError(details);
        }
      };
      // 引擎层未捕获错误:记录后吞掉,避免应用被终止。
      WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
        AppLogger.fatal('Platform', error.toString(), stack);
        return true;
      };
      // 构建期异常用轻量兜底视图替换默认红屏。
      ErrorWidget.builder = (details) => const _ErrorFallback();

      runApp(const App());
    },
    (error, stack) {
      AppLogger.fatal('Zone', error.toString(), stack);
    },
  );
}

/// 构建期错误的轻量兜底视图(替代默认红屏)。
///
/// 构建/布局出错时系统处于不稳定状态,这里尽量少做事:不依赖主题、
/// 媒体查询等可能同样损坏的上下文,仅渲染纯色 + 提示。
class _ErrorFallback extends StatelessWidget {
  const _ErrorFallback();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF141218),
      child: Center(
        child: Text(
          'Something went wrong.\nSee the app log for details.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
