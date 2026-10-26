import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'router.dart';
import 'startup_error_page.dart';
import 'theme.dart';
import '../core/models/accent_color.dart';
import '../core/navigation/back_navigation.dart';
import '../core/navigation/route_observer.dart';
import '../core/services/player_service.dart';
import '../core/services/service_locator.dart';
import '../core/services/sleep_timer_service.dart';
import '../core/utils/keyboard_focus.dart';
import '../core/utils/logger.dart';
import '../features/player/player_page.dart';
import '../features/player/player_ui_state.dart';
import '../features/shell/now_playing_bar.dart';
import '../features/shell/shell_page.dart';
import '../l10n/app_localizations.dart';
import '../l10n/l10n.dart';
import '../widgets/hud_overlay.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _initialized = false;
  Object? _startupError;
  final _navKey = GlobalKey<NavigatorState>();
  final _showBar = ValueNotifier<bool>(true);

  /// 「正在播放」展开进度（0 = 收起，1 = 完全展开），由播放页路由的过渡动画写入。
  final _playerReveal = ValueNotifier<double>(0);

  /// 底栏内容的淡出进度（0 = 不透明）——在 push 播放页**之前**跑完，见 [_openPlayer]。
  late final AnimationController _barFadeOut = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
  );

  /// 播放器跨会话界面状态（重开保留标签/队列滚动位置）。
  final _playerUiState = PlayerUiState();

  /// Shell tab 外部控制（播放页跳歌手/专辑时切 tab）。
  final _shellController = ShellController();

  /// 「返回」的输入分发：鼠标后退侧键 / ⌘[ / 浏览器后退键。
  late final BackNavigationHandler _backNavigation = BackNavigationHandler(
    onBack: _goBack,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 键盘导航退出口（P1）：Esc 取消焦点。注册为 **late** key handler —— 只有
    // 对话框 / 弹层菜单 / 文本框都没处理该键时才轮到这里（详见 utils/keyboard_focus.dart）。
    FocusManager.instance.addLateKeyEventHandler(handleKeyboardFocusKeyEvent);
    // 返回（鼠标后退侧键 / ⌘[ / 浏览器后退键）。与 Esc 一样用 late handler，
    // 不抢输入控件与弹层。
    FocusManager.instance.addLateKeyEventHandler(_backNavigation.handleKey);
    _initializeServices();
  }

  /// 返回一层路由。
  ///
  /// 对话框 / 右键菜单 / BottomSheet 都挂在同一个 Navigator 上，所以它们也是一
  /// 层 —— 会先被关掉，符合「一层一层退」。已经回到主界面（Shell）时什么都不做，
  /// 不切 tab、不退出应用。
  void _goBack() => popTopRoute(_navKey.currentState);

  /// 推进度归零（路由销毁后调用，含 `pushAndRemoveUntil` 这种不走动画的替换），
  /// 并唤醒等它收完的 [_openFromPlayer]。
  ///
  /// 排到帧后：销毁发生在树的 finalize 阶段，此刻直接写会踩「build 期间重建」。
  void _resetPlayerReveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final retracted = _playerRetracted;
      _playerRetracted = null;
      if (!mounted) {
        if (retracted != null && !retracted.isCompleted) retracted.complete();
        return;
      }
      if (_playerReveal.value != 0) _playerReveal.value = 0;
      if (retracted != null && !retracted.isCompleted) retracted.complete();
    });
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
      _playerUiState.lyricWordHighlight =
          ServiceLocator.settings.lyricWordHighlight;
      _playerUiState.lyricWordLift = ServiceLocator.settings.lyricWordLift;
      _playerUiState.lyricLineWave = ServiceLocator.settings.lyricLineWave;
      _playerUiState.lyricDistanceBlur =
          ServiceLocator.settings.lyricDistanceBlur;
      _playerUiState.lyricCountdown = ServiceLocator.settings.lyricCountdown;
      _playerUiState.lyricEffectStrength =
          ServiceLocator.settings.lyricEffectStrength;
      _playerUiState.lyricLineTransition =
          ServiceLocator.settings.lyricLineTransition;
      _playerUiState.lyricSlideAlignment =
          ServiceLocator.settings.lyricSlideAlignment;
      // 注入菜单动作 → 切 tab（仅 macOS 有菜单服务）。
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final menu = ServiceLocator.menu;
        menu.openSettings = _openSettingsFromMenu;
        menu.openAbout = _openAboutFromMenu;
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
      // 点击切歌通知横幅 → 打开「正在播放」页（core 不反向依赖 features，
      // 回调由此注入，与上述 MenuService 的注入方式一致）。
      ServiceLocator.trackNotifications.onOpenPlayer = _openPlayer;
      // 语言切换后歌词的中文翻译副行显示条件会变，重新解析当前歌词。
      // 重试路径可能再次执行，先移除避免重复挂监听。
      ServiceLocator.settings.localeNotifier
        ..removeListener(_onLocaleChanged)
        ..addListener(_onLocaleChanged);
      setState(() => _initialized = true);
    }
  }

  /// 启动失败后重试:清掉失败缓存的初始化 Future 再走一遍。
  void _retry() {
    ServiceLocator.resetInitialization();
    setState(() => _startupError = null);
    _initializeServices();
  }

  /// 界面语言切换：歌词翻译副行是否显示取决于界面语言，需要重新解析。
  void _onLocaleChanged() {
    if (!ServiceLocator.isReady) return;
    ServiceLocator.lyrics.refreshLocaleDependentContent();
    // 系统通知的「下一首」动作标签在插件初始化时注册，切换语言后重新注册。
    unawaited(ServiceLocator.trackNotifications.refreshLocale());
  }

  @override
  void dispose() {
    if (ServiceLocator.isReady) {
      ServiceLocator.settings.localeNotifier.removeListener(_onLocaleChanged);
    }
    WidgetsBinding.instance.removeObserver(this);
    FocusManager.instance.removeLateKeyEventHandler(
      handleKeyboardFocusKeyEvent,
    );
    FocusManager.instance.removeLateKeyEventHandler(_backNavigation.handleKey);
    // 有等待中的"离开播放页"流程时先放行，别让它挂着超时。
    final retracted = _playerRetracted;
    if (retracted != null && !retracted.isCompleted) retracted.complete();
    _playerRetracted = null;
    _barFadeOut.dispose();
    _showBar.dispose();
    _playerReveal.dispose();
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

  /// 菜单「关于本软件」(Help) 动作：与 ⌘, 一样先退回主界面，再切设置 tab
  /// 并让设置页推入「关于」（经 ShellController 广播动作，页面订阅执行）。
  void _openAboutFromMenu() {
    final nav = _navKey.currentState;
    if (nav != null) {
      nav.popUntil((route) => route.isFirst);
    }
    _shellController.request(
      NavigationItem.settings,
      action: ShellAction.openAbout,
    );
  }

  /// 打开播放页的流程进行中（防止连点重复入栈）。
  bool _openingPlayer = false;

  /// 卡片的收回完成信号：`_resetPlayerReveal` 里 resolve。
  Completer<void>? _playerRetracted;

  /// 正在"离开播放页"的流程中（防止连点重复 pop/push）。
  bool _leavingPlayer = false;

  Future<void> _openPlayer() async {
    final nav = _navKey.currentState;
    // 导航未就绪，或播放页已在最上层（_showBar 为 false 即播放页可见，例如
    // 点击切歌通知时页面已经打开）→ 不重复入栈。
    // `_leavingPlayer`：卡片收回中、目标页还没推入。这段空窗里迷你底栏已经挂回，
    // 若允许点开播放页，目标页随后会压到播放页上面。
    if (nav == null || !_showBar.value || _openingPlayer || _leavingPlayer) {
      return;
    }
    _openingPlayer = true;
    try {
      // 点按迷你底栏/通知进入播放页前先对账，确保首屏即引擎真相。
      if (ServiceLocator.isReady) {
        ServiceLocator.player.resyncFromAudio();
      }
      // 底栏内容先淡出，再压入播放页。
      //
      // 顺序不能换：底栏是根 Scaffold 的 bottomNavigationBar，它的去留会改变
      // body 高度，而播放页路由就在 body 里。必须在页面布局**之前**把底栏卸掉，
      // 否则 body 会在动画收尾时变高 64，页面（连同底部控制带）整体往下跳。
      await _barFadeOut.forward(from: 0);
      if (!mounted) return;

      // 底部控制带的 key 同时交给页面与过渡：过渡据此量出带子的真实高度。
      final bandKey = GlobalKey();
      nav.push(
        AppRouter.bottomUpRoute(
          PlayerPage(
            uiState: _playerUiState,
            onOpenDetail: _openDetailFromPlayer,
            bottomBarKey: bandKey,
            reveal: _playerReveal,
          ),
          name: PlayerPage.routeName,
          progress: _playerReveal,
          bandKey: bandKey,
          onDisposed: _resetPlayerReveal,
        ),
      );
    } finally {
      _openingPlayer = false;
      // 底栏此时已卸载，复位只影响下一次收起时的观感。
      _barFadeOut.value = 0;
    }
  }

  /// 从播放页进二级页（歌手/专辑详情、歌词设置等）：**两段式**。
  ///
  /// ① 先 `pop` 播放页 —— 用它的反向动画把卡片收回迷你底栏（复用展开动画，不是
  ///    另一套）。此时 Shell 的 tab 已经切好了（调用方先切），所以卡片收走的过程
  ///    中露出来的是**目标 tab**；
  /// ② 卡片彻底消失后，再把目标页按平台默认方式推入（从右侧滑入）。
  ///
  /// 为什么不能一步完成：播放页是路由，"后压的盖前面的"。想让卡片收回时露出新页，
  /// 新页必须在播放页**下面**，而 `push` 只能往上加；`pushAndRemoveUntil` 会立刻
  /// 移除播放页（底下露出主界面 = 闪一下），`pushReplacement` 则是新页盖着播放页
  /// 滑入（看不到收回）。两段式是当前路由结构下唯一"逻辑正确"的排法。
  Future<void> _openFromPlayer(Widget page) async {
    final nav = _navKey.currentState;
    if (nav == null || _leavingPlayer) return;
    // 置位要让根 Scaffold 重建（收回期间用它挡住点击）。
    setState(() => _leavingPlayer = true);
    try {
      if (!_showBar.value) {
        final retracted = _playerRetracted = Completer<void>();
        nav.pop();
        // 兜底超时：万一反向动画被打断、路由没被销毁，也别把导航卡死。
        await retracted.future.timeout(
          AppRouter.transitionDuration + const Duration(milliseconds: 200),
          onTimeout: () {},
        );
        if (!mounted) return;
      }
      // ② 推入目标页。若栈顶还不是 shell（例如播放页是从某个详情页点开的），用
      //    replace 把那条旧页顶掉 —— 否则「详情 → 播放页 → 详情」会一层层堆起来
      //    （旧代码靠 pushAndRemoveUntil(isFirst) 顺手兜住了，两段式里要显式补上）。
      //    用 replace 而不是 pushAndRemoveUntil：旧页在新页滑入期间仍垫在下面，
      //    不会在滑入过程中露出主界面。
      final next = _navKey.currentState;
      if (next == null) return;
      final route = MaterialPageRoute<void>(builder: (_) => page);
      if (next.canPop()) {
        next.pushReplacement(route);
      } else {
        next.push(route);
      }
    } finally {
      if (mounted) {
        setState(() => _leavingPlayer = false);
      } else {
        _leavingPlayer = false;
      }
      _playerRetracted = null;
    }
  }

  /// 从播放页点歌手/专辑：先切 Shell 的 tab（卡片收回时露出的就是目标 tab），
  /// 再走两段式跳转。
  Future<void> _openDetailFromPlayer(Widget page, NavigationItem tab) async {
    if (_leavingPlayer) return;
    _shellController.tab.value = tab;
    await _openFromPlayer(page);
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
            settings.localeNotifier,
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
          locale: settings?.localeNotifier.value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
            NowPlayingBarVisibilityObserver(_showBar),
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
                  builder: (context) => Listener(
                    // 鼠标「后退」侧键（button 4）。Listener 不进手势竞技场，
                    // 不会和按钮 / 列表行 / 弹层菜单抢手势。
                    onPointerDown: _backNavigation.handlePointerDown,
                    child: Scaffold(
                      // 所有页面（Shell + 子页面 + 播放页）都渲染在底栏上方，底栏不被
                      // 子页面盖住。顶部不再有全局顶栏，改由各页面自行避让（左侧边栏
                      // 顶部预留 45 给红绿灯，右侧内容区用统一高度的 PageToolbar）。
                      // 从播放页跳转的两段式里，卡片收回期间露出来的页面不该能点：
                      // 那时的点击会在目标页推入后被 replace 顶掉，或把播放页推到
                      // 目标页上面。用 AbsorbPointer 而不是 IgnorePointer —— 后者只是
                      // 让子树不参与命中测试，事件仍会穿透到别的 Overlay entry。
                      body: AbsorbPointer(
                        absorbing: _leavingPlayer,
                        child: GestureDetector(
                          // 键盘导航退出口（P3）：点空白处取消焦点。
                          // `translucent` + 根级只当兜底 —— 按钮 / 列表行 / 弹层菜单
                          // 自己的手势会赢下手势竞技场（内层优先），只有「真的没东西
                          // 可点」时才轮到它，不会误伤交互。
                          behavior: HitTestBehavior.translucent,
                          onTap: () => clearKeyboardFocus(),
                          child: _PlayerNoticeConsumer(
                            child: child ?? const SizedBox.shrink(),
                          ),
                        ),
                      ),
                      bottomNavigationBar: ListenableBuilder(
                        listenable: Listenable.merge([
                          _showBar,
                          _playerReveal,
                        ]),
                        builder: (context, _) {
                          // 启动失败时不显示底栏（此时没有播放器/队列）。
                          if (_startupError != null) {
                            return const SizedBox.shrink();
                          }
                          // 只要播放页在栈里（`!_showBar`）或展开动画还在跑
                          // （`_playerReveal > 0`），底栏一律不占位：body 高度必须
                          // 恒定，否则播放页会跟着 body 一起跳。收起动画跑到 0 时
                          // 才重新挂上，此时页面已经不可见，交接无色差。
                          if (!_showBar.value || _playerReveal.value > 0) {
                            return const SizedBox.shrink();
                          }
                          return AbsorbPointer(
                            absorbing: _leavingPlayer,
                            child: _MiniBarSlot(
                              fadeOut: _barFadeOut,
                              onTap: _openPlayer,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // 底部浮动提示（HUD）：**单独一条 entry**，比 Scaffold（连同其上的
                // SnackBar）晚绘制，所以天然浮在最上层，不用往页面树里塞 Stack。
                // `_showBar` 为 false 即「正在播放页在最上层」——那里已有音量滑块、
                // 信息卡与控制按钮，HUD 只会是重复信息，故整层禁用。
                OverlayEntry(
                  builder: (context) => Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: HudOverlay.kBottomInset,
                      ),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _showBar,
                        builder: (context, showBar, _) => HudOverlay(
                          hud: ServiceLocator.hud,
                          enabled: showBar,
                        ),
                      ),
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

/// 全局消费播放错误 / 睡眠定时到点提示，并用 SnackBar 提示。
///
/// 挂在 MaterialApp.builder 的根 Scaffold body 内：任何页面触发播放失败
/// (文件缺失/损坏/权限)或者睡眠定时到点都会弹出提示,不依赖某个页面是否打开。
class _PlayerNoticeConsumer extends StatefulWidget {
  const _PlayerNoticeConsumer({required this.child});

  final Widget child;

  @override
  State<_PlayerNoticeConsumer> createState() => _PlayerNoticeConsumerState();
}

class _PlayerNoticeConsumerState extends State<_PlayerNoticeConsumer> {
  PlayerService? _player;
  SleepTimerService? _sleepTimer;

  /// 惰性挂接监听:启动初始化完成(ServiceLocator 就绪)前不挂。
  ///
  /// 在 [build] 中调用以利用 _AppState 初始化完成后的重建时机自动挂上。
  void _maybeAttach() {
    if (!ServiceLocator.isReady) return;
    if (_player == null) {
      _player = ServiceLocator.player;
      _player!.addListener(_onPlayerChanged);
    }
    if (_sleepTimer == null) {
      _sleepTimer = ServiceLocator.sleepTimer;
      _sleepTimer!.notice.addListener(_onSleepTimerNotice);
    }
  }

  void _onPlayerChanged() {
    final err = _player!.takePlaybackError();
    if (err == null || !mounted) return;
    final l10n = context.l10n;
    final message = switch (err.kind) {
      PlaybackFailureKind.loadFailed =>
        err.title == null
            ? l10n.playbackFailedNoTitle
            : l10n.playbackFailedWithTitle(err.title!),
      PlaybackFailureKind.repeatedFailures => l10n.playbackFailedRepeated(
        err.consecutiveCount ?? 0,
      ),
    };
    // 连跳多首坏文件时会连续产生提示：**替换**当前提示而不是排队，否则会积起
    // 一串"无法播放"按顺序慢慢弹完（观感很差，且滞后于真实进度）。
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// 睡眠定时到点：提示一次（到点时可能不在播放页，按钮状态的变化未必看得到）。
  void _onSleepTimerNotice() {
    final notice = _sleepTimer!.takeNotice();
    if (notice == null || !mounted) return;
    final l10n = context.l10n;
    final message = switch (notice) {
      SleepTimerNotice.expiredWaitingForTrack => l10n.sleepTimerExpiredWaiting,
      SleepTimerNotice.finishedPaused => l10n.sleepTimerFinishedPaused,
      SleepTimerNotice.finishedStopped => l10n.sleepTimerFinishedStopped,
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _player?.removeListener(_onPlayerChanged);
    _sleepTimer?.notice.removeListener(_onSleepTimerNotice);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _maybeAttach();
    return widget.child;
  }
}

/// 全屏“正在播放”页在路由栈里时隐藏底栏，关闭后恢复显示。
///
/// 必须看整条栈而不是只看栈顶：从播放页再压入歌词设置等子页面时，栈顶不是
/// [PlayerPage]，但底栏仍应保持隐藏；否则点底栏会再压入一个播放页，形成
/// 播放页 → 设置 → 播放页 → 设置 的套娃。
class NowPlayingBarVisibilityObserver extends NavigatorObserver {
  NowPlayingBarVisibilityObserver(this.showBar);

  final ValueNotifier<bool> showBar;
  final List<Route<dynamic>> _pageRoutes = [];

  bool _isPlayer(Route<dynamic> route) =>
      route.settings.name == PlayerPage.routeName;

  void _sync() {
    showBar.value = !_pageRoutes.any(_isPlayer);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    // 只响应真正的页面路由：PopupMenu/Dialog/BottomSheet 等弹层路由
    // 不是 PageRoute，忽略以免（如弹出歌曲菜单时）误触发底栏显隐。
    if (route is! PageRoute) return;
    _pageRoutes.add(route);
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _pageRoutes.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _pageRoutes.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute is PageRoute) _pageRoutes.remove(oldRoute);
    if (newRoute is PageRoute) _pageRoutes.add(newRoute);
    _sync();
  }
}

/// 迷你底栏槽位：播放页展开前先淡出**内容**，条子背景保持不透明。
///
/// 底栏自己的背景（`surfaceContainerLow`）若跟着淡出，会闪一下底下的列表；
/// 外层 [ColoredBox] 同色兜住即可。淡出结束后底栏紧接着被卸载，播放页自己的
/// 底部带子以同样的矩形/颜色接管。
class _MiniBarSlot extends StatelessWidget {
  const _MiniBarSlot({required this.fadeOut, required this.onTap});

  /// 淡出进度（0 = 完全不透明，1 = 内容已不可见）。
  final Animation<double> fadeOut;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      // 进来时淡入：底栏要等收起动画结束才重新挂上，直接整块出现会和"刚淡掉的
      // 控制行"撞在一起。
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: NowPlayingBar(onTap: onTap),
        builder: (context, enter, child) => AnimatedBuilder(
          animation: fadeOut,
          child: child,
          builder: (context, child) => Opacity(
            opacity: ((1 - fadeOut.value) * enter).clamp(0.0, 1.0),
            child: child,
          ),
        ),
      ),
    );
  }
}
