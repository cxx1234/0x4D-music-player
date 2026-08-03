import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';

import 'theme.dart';
import 'router.dart';
import '../core/services/service_locator.dart';
import '../features/player/player_page.dart';
import '../features/shell/now_playing_bar.dart';
import '../features/shell/shell_page.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _initialized = false;
  final _navKey = GlobalKey<NavigatorState>();
  final _showBar = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    ServiceLocator.initialize().then((_) async {
      try {
        await MetadataGod.initialize();
        debugPrint('MetadataGod initialized successfully');
      } catch (e) {
        debugPrint('MetadataGod initialization failed: $e');
      }
      if (mounted) {
        setState(() => _initialized = true);
      }
    });
  }

  @override
  void dispose() {
    _showBar.dispose();
    super.dispose();
  }

  void _openPlayer() {
    _navKey.currentState!.push(
      AppRouter.bottomUpRoute(const PlayerPage(), name: PlayerPage.routeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Music',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ShellPage(isInitialized: _initialized),
      onGenerateRoute: AppRouter.generateRoute,
      navigatorKey: _navKey,
      navigatorObservers: [_NowPlayingBarVisibilityObserver(_showBar)],
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        // 根 Overlay 包裹整个应用：底栏位于 Navigator（含 Overlay）之外，
        // 没有这个根 Overlay，底栏里的 Tooltip 等依赖 Overlay 的组件
        // 会报 "No Overlay widgets found"。
        return Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Scaffold(
                // 所有页面（Shell + 子页面 + 播放页）都渲染在底栏上方，
                // 底栏因此全局常驻、子页面不再盖住它。
                body: child,
                bottomNavigationBar: ValueListenableBuilder<bool>(
                  valueListenable: _showBar,
                  builder: (context, show, _) {
                    // 全屏“正在播放”打开时隐藏底栏，关闭后恢复。
                    if (!show) return const SizedBox.shrink();
                    return NowPlayingBar(onTap: _openPlayer);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 全屏“正在播放”页打开时隐藏底栏，关闭后恢复显示。
class _NowPlayingBarVisibilityObserver extends NavigatorObserver {
  _NowPlayingBarVisibilityObserver(this.showBar);

  final ValueNotifier<bool> showBar;

  bool _isPlayer(Route<dynamic> route) =>
      route.settings.name == PlayerPage.routeName;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    showBar.value = !_isPlayer(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    showBar.value = previousRoute == null || !_isPlayer(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    showBar.value = previousRoute == null || !_isPlayer(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    showBar.value = newRoute == null || !_isPlayer(newRoute);
  }
}
