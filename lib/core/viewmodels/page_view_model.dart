import 'dart:async';

import 'package:flutter/foundation.dart';

import '../utils/logger.dart';

/// 页面 ViewModel 基类：统一「已销毁守卫 + 安全通知 + 实时查询订阅」。
///
/// 页面 State 持有 VM 实例：`initState` 里 `addListener`、`dispose` 里
/// `removeListener` + `vm.dispose()`。VM 内异步方法（await 之后再通知）一律走
/// [safeNotify]，避免页面已销毁后 "used after being disposed"。
abstract class PageViewModel extends ChangeNotifier {
  bool _disposed = false;

  bool _loading = true;

  /// 已订阅的实时查询（dispose 时统一取消，避免数据库流泄漏）。
  final List<StreamSubscription<Object?>> _streamSubscriptions = [];

  /// 是否正在首次加载（浏览页据此显示转圈；后续实时更新不置位避免闪烁）。
  bool get loading => _loading;

  /// VM 是否已销毁：跨帧的异步流程（`endOfFrame` 之后再干活）据此早退。
  @protected
  bool get isDisposed => _disposed;

  @protected
  void setLoading(bool value) {
    _loading = value;
  }

  /// 安全通知：VM 已销毁时静默跳过（异步回调在页面销毁后到达的兜底）。
  @protected
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  /// 订阅一条实时查询：数据变化 → [onData]；流报错记日志并保留上一帧数据
  /// （页面不闪断）；VM 销毁时统一取消。
  @protected
  StreamSubscription<T> trackStream<T>(
    Stream<T> stream,
    void Function(T value) onData,
  ) {
    final subscription = stream.listen(
      (value) {
        if (_disposed) return;
        onData(value);
      },
      onError: (Object e, StackTrace s) {
        AppLogger.error('DB', 'Live query failed', e, s);
      },
    );
    _streamSubscriptions.add(subscription);
    return subscription;
  }

  @override
  void dispose() {
    _disposed = true;
    for (final subscription in _streamSubscriptions) {
      unawaited(subscription.cancel());
    }
    _streamSubscriptions.clear();
    super.dispose();
  }
}
