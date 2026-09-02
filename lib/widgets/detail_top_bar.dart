import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/layout.dart';
import '../core/navigation/route_observer.dart';

/// 详情页顶部栏：返回键 + 左对齐标题 + 可选操作，替代二级页的 M3 AppBar。
/// 作为 Scaffold 的 `appBar:` 槽位使用（实现 [PreferredSizeWidget]，body 无需改动）。
///
/// - 左侧在 macOS 上预留 [PlatformLayoutConfig.detailTopBarLeftInset]（95）
///   让过红绿灯组；其余平台为 0（Windows 不生效）。
/// - 返回键与右侧功能按钮通过 [IconButtonTheme] 统一尺寸：图标 22、命中区 36×36。
/// - 标题 `titleMedium`（16）左对齐、单行省略，距左侧按钮约一个按钮宽度。
/// - 「播放全部」等大操作不放这一栏，由页面自行放置。
///
/// 使用：
/// ```dart
/// Scaffold(
///   appBar: DetailTopBar(title: album.name),
///   body: ...,
/// )
/// ```
class DetailTopBar extends StatefulWidget implements PreferredSizeWidget {
  const DetailTopBar({super.key, required this.title, this.actions});

  final String title;

  /// 右侧操作区（可空；宽度会上报给 macOS 原生，用于顶栏双击拦截）。
  final List<Widget>? actions;

  @override
  Size get preferredSize => Size.fromHeight(layoutConfig.detailTopBarHeight);

  @override
  State<DetailTopBar> createState() => _DetailTopBarState();
}

class _DetailTopBarState extends State<DetailTopBar> with RouteAware {
  static const _channel = MethodChannel('com.jerryc.txvziwm/window');

  /// 最近测量的 actions 组宽度（逻辑像素；0 = 无 actions，右区不拦）。
  double _actionsWidth = 0;
  final _actionsKey = GlobalKey();

  /// 当前已订阅的 ModalRoute（RouteAware 去重，路由变化时重订阅）。
  ModalRoute<dynamic>? _subscribedRoute;

  @override
  void initState() {
    super.initState();
    _setTopBarGuard(true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ModalRoute 是 inherited widget，只能在 didChangeDependencies 里读取；
    // 路由变化（push/pop）时重订阅 RouteAware。
    final route = ModalRoute.of(context);
    if (!identical(route, _subscribedRoute)) {
      if (_subscribedRoute != null) routeObserver.unsubscribe(this);
      if (route != null) routeObserver.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _setTopBarGuard(false);
    _reportActionsWidth(0);
    super.dispose();
  }

  // 被上层路由覆盖：右区拦截交给上层（上报 0，避免残留旧宽度误拦）。
  @override
  void didPushNext() => _reportActionsWidth(0);

  // 上层 pop 后自己重新可见：恢复自己最新的 actions 宽度。
  @override
  void didPopNext() => _reportActionsWidth(_actionsWidth);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionsList = widget.actions;
    final hasActions = actionsList != null && actionsList.isNotEmpty;
    // 每次布局后测量 actions 宽度（仅宽度变化时上报原生）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureAndReport());

    return Padding(
      padding: EdgeInsets.only(
        left: layoutConfig.detailTopBarLeftInset,
        right: 12,
      ),
      child: IconButtonTheme(
        // 返回键与右侧功能按钮统一尺寸：图标 22、内边距 8（命中区为 M3 默认 48，天然统一）。
        data: IconButtonThemeData(
          style: IconButton.styleFrom(
            iconSize: 20,
            padding: const EdgeInsets.all(8),
          ),
        ),
        child: SizedBox(
          height: layoutConfig.detailTopBarHeight,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              // 文本离左侧按钮约一个按钮（hover 区域）宽度。
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              if (hasActions)
                Row(
                  key: _actionsKey,
                  mainAxisSize: MainAxisSize.min,
                  children: actionsList,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 测量 actions 组宽度（逻辑像素），变化时才上报给 macOS 原生。
  void _measureAndReport() {
    if (!mounted) return;
    final box = _actionsKey.currentContext?.findRenderObject();
    final width = (box is RenderBox && box.hasSize) ? box.size.width : 0.0;
    if (width != _actionsWidth) {
      _actionsWidth = width;
      _reportActionsWidth(width);
    }
  }

  /// 仅 macOS：DetailTopBar 出现/销毁时同步原生顶栏拦截开关。
  void _setTopBarGuard(bool enabled) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _channel.invokeMethod('setTopBarGuard', enabled);
    }
  }

  /// 仅 macOS：上报 actions 组宽度（逻辑像素），原生按右缘反推拦截区。
  void _reportActionsWidth(double width) {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      _channel.invokeMethod('setActionsWidth', width);
    }
  }
}
