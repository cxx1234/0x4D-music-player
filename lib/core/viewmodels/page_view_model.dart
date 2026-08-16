import 'package:flutter/foundation.dart';

/// 页面 ViewModel 基类：统一「已销毁守卫 + 安全通知 + 首载/刷新 loading 模板」。
///
/// 页面 State 持有 VM 实例：`initState` 里 `addListener`、`dispose` 里
/// `removeListener` + `vm.dispose()`。VM 内异步方法（await 之后再通知）一律走
/// [safeNotify]，避免页面已销毁后 "used after being disposed"。
abstract class PageViewModel extends ChangeNotifier {
  bool _disposed = false;

  bool _loading = true;

  /// 是否正在首次加载（浏览页据此显示转圈；刷新不置位避免闪烁）。
  bool get loading => _loading;

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

  /// 通用加载模板：无数据时置 loading 并通知；刷新（已有数据）不闪 loading；
  /// `finally` 里无论成败都复位并通知。
  ///
  /// [hasData] 由调用方在发起加载前同步求值，决定是否显示首载转圈。
  @protected
  Future<void> runLoad(
    Future<void> Function() action, {
    required bool hasData,
  }) async {
    if (!hasData) {
      setLoading(true);
      safeNotify();
    }
    try {
      await action();
    } finally {
      setLoading(false);
      safeNotify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
