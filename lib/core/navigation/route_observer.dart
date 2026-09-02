import 'package:flutter/widgets.dart';

/// 全局路由观察器：供需要感知「被上层路由覆盖 / 重新可见」的组件
/// （如 [DetailTopBar] 上报 actions 宽度）订阅。
final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();
