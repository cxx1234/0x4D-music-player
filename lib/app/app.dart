import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'router.dart';
import 'startup_error_page.dart';
import 'theme.dart';
import '../core/constants/layout.dart';
import '../core/models/accent_color.dart';
import '../core/navigation/route_observer.dart';
import '../core/services/player_service.dart';
import '../core/services/service_locator.dart';
import '../core/utils/logger.dart';
import '../features/player/player_page.dart';
import '../features/player/player_ui_state.dart';
import '../features/shell/now_playing_bar.dart';
import '../features/shell/shell_page.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  bool _initialized = false;
  Object? _startupError;
  final _navKey = GlobalKey<NavigatorState>();
  final _showBar = ValueNotifier<bool>(true);

  /// 播放器跨会话界面状态（重开保留标签/队列滚动位置）。
  final _playerUiState = PlayerUiState();

  /// Shell tab 外部控制（播放页跳歌手/专辑时切 tab）。
  final _shellController = ShellController();

  /// 与原生层（MainFlutterWindow.swift）通信的通道。
  static const _windowChannel = MethodChannel('com.jerryc.txvziwm/window');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 首帧后将顶部高度参数同步给原生层（红绿灯定位用）。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTopBarHeightToNative();
    });
    _initializeServices();
  }

  /// 初始化核心服务(幂等),失败时进入启动错误页。
  Future<void> _initializeServices() async {
    try {
      await ServiceLocator.initialize();
    } catch (e, s) {
      AppLogger.fatal('Startup', 'ServiceLocator.initialize() failed', e, s);
      if (mounted) {
        setState(() => _startupError = e);
      }
      return;
    }
    // audio_metadata_reader 为纯 Dart 库，无需原生初始化。
    if (mounted) {
      // 歌词 UI 状态（字号/翻译）从持久化设置恢复（设置页不展示，跨重启保留）。
      _playerUiState.lyricTextSize = ServiceLocator.settings.lyricTextSize;
      _playerUiState.showTranslation = ServiceLocator.settings.showTranslation;
      // 注入菜单动作 → 切 tab（仅 macOS 有菜单服务）。
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final menu = ServiceLocator.menu;
        menu.openSettings = _openSettingsFromMenu;
        menu.openPlaylists = () => _shellController.request(
          NavigationItem.playlists,
          action: ShellAction.newPlaylist,
        );
        menu.openLibrary = () => _shellController.request(
          NavigationItem.library,
          action: ShellAction.importFolder,
        );
        menu.openImportPlaylist = () => _shellController.request(
          NavigationItem.playlists,
          action: ShellAction.importPlaylist,
        );
        menu.openExportPlaylist = () => _shellController.request(
          NavigationItem.playlists,
          action: ShellAction.exportPlaylist,
        );
      }
      setState(() => _initialized = true);
    }
  }

  /// 启动失败后重试:清掉失败缓存的初始化 Future 再走一遍。
  void _retry() {
    ServiceLocator.resetInitialization();
    setState(() => _startupError = null);
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _showBar.dispose();
    _shellController.dispose();
    super.dispose();
  }

  /// 应用生命周期挂起/退出前把待写的持久化落盘（防抖窗口内的队列变更）。
  ///
  /// macOS 关窗驻留后台不退出，正常运行的防抖定时器会照常触发；这里是
  /// 对强制退出/系统休眠等场景的兜底。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      unawaited(ServiceLocator.flushPendingWrites());
    }
  }

  /// 将左侧边栏顶部预留高度（layoutConfig.sidebarTopInset）传给原生层，用于红绿灯定位。
  Future<void> _syncTopBarHeightToNative() async {
    // 红绿灯仅 macOS 有；其他平台没有该 MethodChannel handler，
    // 不调用可避免 MissingPluginException 噪音。
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    try {
      await _windowChannel.invokeMethod(
        'setTopBarHeight',
        layoutConfig.sidebarTopInset,
      );
    } catch (e) {
      AppLogger.warning('App', 'Failed to sync top bar height to native', e);
    }
  }

  /// 菜单「偏好设置…」(⌘,) 动作：先关闭「正在播放」等子页回到主界面，
  /// 再切到设置 tab。
  void _openSettingsFromMenu() {
    final nav = _navKey.currentState;
    if (nav != null) {
      // 播放页/详情页是 push 的子路由，切 tab 前先退回主页面（Shell）。
      nav.popUntil((route) => route.isFirst);
    }
    _shellController.tab.value = NavigationItem.settings;
  }

  void _openPlayer() {
    // 点按迷你底栏进入播放页前先对账，确保首屏即引擎真相。
    if (ServiceLocator.isReady) {
      ServiceLocator.player.resyncFromAudio();
    }
    _navKey.currentState!.push(
      AppRouter.bottomUpRoute(
        PlayerPage(
          uiState: _playerUiState,
          onOpenDetail: _openDetailFromPlayer,
        ),
        name: PlayerPage.routeName,
      ),
    );
  }

  /// 从播放页点歌手/专辑：推入详情页并清掉 shell 之上的所有路由
  /// （播放器 + 之前可能残留的详情页），返回落到主页并让 Shell 切到对应 tab。
  void _openDetailFromPlayer(Widget page, NavigationItem tab) {
    _shellController.tab.value = tab;
    _navKey.currentState!.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (route) => route.isFirst,
    );
  }

  /// 主题兜底 notifier：ServiceLocator 就绪前 MaterialApp 也能稳定监听。
  static final _fallbackThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);
  static final _fallbackAccent = ValueNotifier<AccentColor>(
    AccentColor.graphite,
  );
  static final _fallbackSystemAccent = ValueNotifier<Color?>(null);

  @override
  Widget build(BuildContext context) {
    // 主题外观（明暗模式 + 主题色 + 跟随系统的强调色）由 SettingsService /
    // SystemAccentService 广播：任一变化都触发 MaterialApp 重建换肤。
    // ServiceLocator 就绪前用静态兜底 notifier，就绪后切到真实服务源。
    final settings = ServiceLocator.isReady ? ServiceLocator.settings : null;
    final systemAccent = ServiceLocator.isReady
        ? ServiceLocator.systemAccent
        : null;

    final themeListenable = settings != null
        ? Listenable.merge([
            settings.themeModeNotifier,
            settings.accentColorNotifier,
            systemAccent?.systemAccentNotifier ?? _fallbackSystemAccent,
          ])
        : Listenable.merge([
            _fallbackThemeMode,
            _fallbackAccent,
            _fallbackSystemAccent,
          ]);

    return ListenableBuilder(
      listenable: themeListenable,
      builder: (context, _) {
        final themeMode = settings?.themeMode ?? _fallbackThemeMode.value;
        final accent = settings?.accentColor ?? _fallbackAccent.value;
        final systemColor = systemAccent?.systemAccentNotifier.value;
        // 「跟随系统」直用系统强调色；拿不到时 seedColor 回退默认石墨灰。
        final seed = accent.seedColor(systemColor);
        // 石墨灰默认 = 真·无彩色（monochrome，不走 fromSeed，避免灰 seed 派生偏色）；
        // 跟随系统但拿不到系统色时兜底到石墨灰观感，同样走 monochrome。
        final neutral =
            accent == AccentColor.graphite ||
            (accent.followsSystem && systemColor == null);
        return MaterialApp(
          title: '0x4D',
          theme: neutral
              ? AppTheme.monochrome(brightness: Brightness.light)
              : AppTheme.light(seed: seed),
          darkTheme: neutral
              ? AppTheme.monochrome(brightness: Brightness.dark)
              : AppTheme.dark(seed: seed),
          themeMode: themeMode,
          home: _startupError != null
              ? StartupErrorPage(error: _startupError!, onRetry: _retry)
              : ShellPage(
                  isInitialized: _initialized,
                  controller: _shellController,
                ),
          onGenerateRoute: AppRouter.generateRoute,
          navigatorKey: _navKey,
          navigatorObservers: [
            _NowPlayingBarVisibilityObserver(_showBar),
            routeObserver,
          ],
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            // 根 Overlay 包裹整个应用：底栏位于 Navigator（含 Overlay）之外，
            // 没有这个根 Overlay，底栏里的 Tooltip 等依赖 Overlay 的组件
            // 会报 "No Overlay widgets found"。
            return Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (context) => Scaffold(
                    // 所有页面（Shell + 子页面 + 播放页）都渲染在底栏上方，底栏不被
                    // 子页面盖住。顶部不再有全局顶栏，改由各页面自行避让（左侧边栏
                    // 顶部预留 45 给红绿灯，右侧内容区用统一高度的 PageToolbar）。
                    body: _PlaybackErrorConsumer(
                      child: child ?? const SizedBox.shrink(),
                    ),
                    bottomNavigationBar: ValueListenableBuilder<bool>(
                      valueListenable: _showBar,
                      builder: (context, show, _) {
                        // 全屏“正在播放”打开时隐藏底栏，关闭后恢复。
                        // 启动失败时不显示底栏（此时没有播放器/队列）。
                        if (!show || _startupError != null) {
                          return const SizedBox.shrink();
                        }
                        return NowPlayingBar(onTap: _openPlayer);
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 全局消费播放错误并用 SnackBar 提示。
///
/// 挂在 MaterialApp.builder 的根 Scaffold body 内：任何页面触发播放失败
/// (文件缺失/损坏/权限)都会弹出提示,不依赖某个页面是否打开。
class _PlaybackErrorConsumer extends StatefulWidget {
  const _PlaybackErrorConsumer({required this.child});

  final Widget child;

  @override
  State<_PlaybackErrorConsumer> createState() => _PlaybackErrorConsumerState();
}

class _PlaybackErrorConsumerState extends State<_PlaybackErrorConsumer> {
  PlayerService? _player;

  /// 惰性挂接播放器监听:启动初始化完成(ServiceLocator 就绪)前不挂。
  ///
  /// 在 [build] 中调用以利用 _AppState 初始化完成后的重建时机自动挂上。
  void _maybeAttach() {
    if (_player != null || !ServiceLocator.isReady) return;
    _player = ServiceLocator.player;
    _player!.addListener(_onPlayerChanged);
  }

  void _onPlayerChanged() {
    final err = _player!.takePlaybackError();
    if (err == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _maybeAttach();
    return widget.child;
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
    // 只响应真正的页面路由：PopupMenu/Dialog/BottomSheet 等弹层路由
    // 不是 PageRoute，忽略以免（如弹出歌曲菜单时）误触发底栏显隐。
    if (route is! PageRoute) return;
    showBar.value = !_isPlayer(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    showBar.value = previousRoute == null || !_isPlayer(previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    showBar.value = previousRoute == null || !_isPlayer(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute is! PageRoute) return;
    showBar.value = !_isPlayer(newRoute);
  }
}
