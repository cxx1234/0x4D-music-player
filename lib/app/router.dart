import 'package:flutter/material.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => const SizedBox.shrink(),
      settings: settings,
    );
  }

  /// 从底部滑入的路由（用于“正在播放”从底栏展开，关闭时滑回下方）。
  static Route<void> bottomUpRoute(Widget page, {String? name}) {
    return PageRouteBuilder<void>(
      settings: name != null ? RouteSettings(name: name) : null,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }
}
