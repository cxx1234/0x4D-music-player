# Pitfalls — 踩坑登记册

**入册标准**：能**复发**的坑 —— 环境 / 工具链 / 平台差异、SDK 与第三方库的意外行为、
框架层竞态。一次性的笔误、纯业务逻辑 bug 不记。

**与领域文档的分工**：

- 规范性的「必须 / 禁止」留在领域文档（`UI-Rules.md`、`Performance-Optimization.md`、
  `ErrorHandling.md`、`AudioEngine-Migration.md`）—— 改那块代码的人自然会翻到；
- 本册收**跨领域的事故经过**（症状 → 根因 → 修法 → 护栏），领域内的历史经过见文末
  § 索引。

**条目模板**

```
## YYYY-MM-DD 标题（一句话）
- 症状：
- 根因：
- 修法：
- 护栏：测试 / 文档章节 / 代码注释位置
- 复发提示：动手前先看哪一行
```

## A. 构建与工具链

### A1. 2026-08-23 Homebrew z3 升级 → brew LLVM 启动即 SIGABRT

- **症状**：`flutter build macos --debug` 失败，cargokit 编译 `metadata_god`（Rust）报
  `error: process didn't exit successfully: rustc -vV (signal: 6, SIGABRT)`。
- **根因**：Homebrew `z3` 升到 5.1.0（`libz3.4.16.dylib` → `libz3.5.1.dylib`），而旧版
  brew `llvm` 的 `libLLVM.dylib` 仍链接旧库名 —— 任何加载 brew libLLVM 的程序启动即崩。
  检测：`otool -L /usr/local/Cellar/llvm/*/lib/libLLVM.dylib | grep z3`、
  `brew list --versions llvm z3`。
- **修法**：`brew upgrade llvm`（22.1.8 → 22.1.8_2）。下载慢可设
  `HOMEBREW_BOTTLE_DOMAIN=https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles`。
  清理失败残留用 `rm -rf build/macos/Build/Intermediates.noindex/Pods.build/Debug/metadata_god.build`
  （**勿用 `flutter clean`**，本仓库已知它会卡 SPM）。
- **护栏**：验证 `/usr/local/opt/llvm/bin/clang --version` 不再崩 + `rustup run stable cargo build -p metadata_god`。
- **复发提示**：`rustup` 的 rustc **不依赖** brew LLVM（自包含），只有 brew 的 `rust`
  formula 依赖 —— 所以这类崩溃先怀疑 brew `llvm` × `z3` 的链接，不是 Rust 本身。
- **已知无害警告**（不要追）：metadata_god 不支持 SPM；ld deployment target 12.0 vs
  metadata_god.framework 14.0。

### A2. 2026-08-25 切 Flutter 版本后 macOS 编译失败（.pcm 模块缓存过期）

- **症状**：`flutter run --profile` 报
  `FlutterMacOS.framework/Headers/*.h has been modified since the module file .pcm was built: size changed (was 6403, now 6038)`，BUILD FAILED（发生在 file_picker_darwin 编译处）。
- **根因**：`build/macos` 里的 Swift 显式模块缓存 `.pcm` 是按旧版本头文件编译的；版本切换后头文件字节数变了，但模块没重建。
- **修法**：`rm -rf build/macos` 后重跑（**勿用 `flutter clean`**）。首次全量重编慢属正常。
- **护栏**：无（环境操作）。

### A3. 2026-08-30 pbxproj 手工登记 `.lproj/Localizable.strings`

- **症状**：Xcode 报 `Build input file cannot be found`，找不到 `*.lproj`。
- **根因**：需要建 **PBXVariantGroup**（children = 各语言 PBXFileReference，
  `lastKnownFileType = text.plist.strings`）+ PBXBuildFile + 加进 Resources 组 + Resources
  构建阶段 + `knownRegions` 加 `"zh-Hans"`；而 variant group **必须设 `path = Runner`**，
  否则 Xcode 会去 `macos/` 下找（Resources group 的 `path=..` 已指到 `macos/`）。
- **修法**：按上述字段补齐，勿只加 PBXFileReference。
- **护栏**：新增本地化语言时照此清单核对。

### A4. 2026-10-30 `flutter pub get` 会往 `analysis_options.yaml` 里塞平台 exclude

- **症状**：删掉 `android/`、`ios/`、`web/` 三个目录后，手工把 `analysis_options.yaml`
  `analyzer.exclude` 里对应的三条删掉，再跑 `flutter pub get` 又冒出来（打印
  `Upgrading analysis_options.yaml to exclude build and platform directories.`）。
- **根因**：flutter 工具在 `pub get` 时按**磁盘上实际存在的平台目录**重写这段 exclude。
  目录还在时它就会加回去 —— 本次排查中 `git stash` 一度把删掉的目录复原，工具随即把
  `android/**`、`ios/**` 又写了进去，git 里就出现了「刚删的规则又回来」的假象。
- **修法**：先让目录真正消失（含残留的生成物），再跑 `flutter pub get`；确认目录不存在后
  工具不会再写回。若已写回，删掉再 `pub get` 一次即可。
- **护栏**：改 `analysis_options.yaml` 的平台 exclude 前，先 `ls -d */` 确认真实目录；
  `pub get` 输出里出现 `Upgrading ...` 就跑一次 `git diff` 复核，别直接提交。
- **复发提示**：`analysis_options.yaml` 不是纯静态配置，flutter 工具会改它。

## B. macOS 原生层

### B1. 2026-08-30 顶栏双击缩放拦截（DetailTopBar 按钮区）

- **症状**：系统设置开着「双击标题栏缩放」时，快速双击返回键 / actions → 第一次点击生效、第二次被 AppKit 当标题栏双击 → 窗口缩放。
- **根因**：`fullSizeContentView` + unified toolbar 下，双击缩放作用于整个顶部 52pt。
- **修法**：Dart 侧 `detail_top_bar.dart` 上报 guard 计数 + 实测 actions 宽度（`setActionsWidth`，逻辑像素），原生 `MainFlutterWindow.swift` 的 `NSWindow.sendEvent` 里命中区域则吞掉事件。
- **实测教训（踩过才知道）**：
  1. **down 和 up 都要拦** —— 缩放由第二次 down **或** up 触发，只拦 down 仍会缩放；
  2. 原生坐标用 **AppKit points**，与 Flutter 逻辑像素 1:1，**不要乘 `backingScaleFactor`**；
  3. **Flutter `localToGlobal` 在 macOS 返回屏幕坐标**（含窗口位置偏移），不能用于窗口内判定 —— 定坐标靠布局固定值（`detailTopBarLeftInset`=95、返回键命中区实测 **40**、右 padding 12）+ actions 实测宽度上报；
  4. 订阅 `ModalRoute.of` 必须在 `didChangeDependencies`（initState 里读会崩
     `dependOnInheritedWidgetOfExactType<_ModalScopeStatus>() was called before initState completed`）。
- **权衡**：拦截后快速双击按钮只触发一次点击（第二次被原生吞掉）。要两次需手动合成事件转发，成本高，未做。
- **护栏**：`docs/UI-Rules.md` §2；`routeObserver` 在 `lib/core/navigation/route_observer.dart`。

### B2. 2026-08-30/31 ⌘.（Command-Period）菜单快捷键完全失效

- **症状**：菜单项 `keyEquivalent: "."` 配置正确，但按 ⌘. 无反应，菜单栏也不高亮。
- **根因**：**Flutter macOS embedder 在 `NSWindow.sendEvent` 之前就把 ⌘. 当"取消/停止"**（等价 Escape）拦截并转发给 Dart（Dart 侧同时收到 `key=46 "."` 与 Escape），菜单系统（在 sendEvent 里）**根本收不到这个组合键**。对照：单独 Esc（keyCode 53）不被拦、⌘, 正常 —— Flutter 只特殊处理 ⌘.。
- **修法**：`NSEvent.addLocalMonitorForEvents(matching: .keyDown)`（**先于 Flutter 引擎的 monitor**）按 `keyCode == 47 && .command` 截住，然后**优先 `NSApp.mainMenu?.performKeyEquivalent(with: event)`** 让菜单系统走标准匹配（既有功能又有菜单栏高亮），匹配失败才兜底 `sendMenuAction("stop")`。
- **反面教训**：① **不要 override `NSWindow.performKeyEquivalent`** —— 打断 AppKit 事件链会让 Esc 无限递归卡死；② 菜单栏高亮无公开 API，只能靠菜单系统标准匹配拿到。
- **护栏**：`macos/Runner/AppDelegate.swift` 的 `installKeyShortcutMonitor()`。
- **复发提示**：Flutter 应用里任何菜单快捷键失效，先查是不是 embedder 在 sendEvent 前拦了（local monitor 打印 + 窗口 sendEvent 探针对比）。

### B3. 2026-08-31 此 SDK（macOS 26.2 / AppKit）与 iOS 的 API 差异

写 macOS 原生代码时别照搬 iOS 记忆：

1. **`NSColor` 没有 `resolvedColor(with:)`**（iOS `UIColor` 有）—— 取动态系统色直接
   `NSColor.controlAccentColor.usingColorSpace(.sRGB)`（主线程按当前外观解析）。
2. **`NSWorkspace` 没有 `didChangeWallpaperNotification`** —— "随壁纸派生的 Multicolor"
   实时跟随**无 API**；改用「应用回到前台」+ `AppleColorPreferencesChangedNotification`
   （改强调色）+ `AppleInterfaceThemeChangedNotification`（明暗切换）三条通知兜底。
3. **`NSColor.getRed(...)` 返回 `Void`**（iOS `UIColor` 返回 `Bool`）—— 不能
   `guard let` / `if`，直接调用即成功。
4. **分布式通知的 block 观察者 token 必须强引用保存**，否则收不到。
5. MethodChannel 双向推送：原生 `channel.invokeMethod` 需先把 channel 存成属性。

- **护栏**：`lib/core/services/system_accent_service.dart` 同款注释。

### B4. 2026-08-30 `NSMenuItem` 想用裸空格必须显式清修饰键

- **症状**：`keyEquivalent: " "` 显示成 `⌘空格`。
- **修法**：显式 `keyEquivalentModifierMask = []`（Apple Music 风格裸空格）。
- **复发提示**：任何"想不带 ⌘ 的键等价"都要写这一行。

### B5. 2026-09-21 通知附件不要直接给应用容器里的封面文件

- **症状**：切歌通知用缓存封面后，缓存文件从应用容器里**消失**（封面在别处变空白）。
- **根因**：macOS 会把不在 app bundle 内的附件**搬进自己的存储**；把 `Documents/covers/*.jpg`
  交出去 = 被搬走（= 应用侧被删）。换成沙盒 temp 目录也不行 —— 系统读不回该目录，缩略图静默消失。
- **修法**：通知前把封面**复制一份**到 `Documents/notif_attachments`，把**副本**交给插件。
- **护栏**：`lib/core/services/track_notification_service.dart`；CHANGELOG 0.2.6 Fixed。

### B6. 2026-08-30 `NSApp.mainMenu?.update()` 刷新子菜单 state 不彻底

- **症状**：播放模式勾选不随状态同步。
- **修法**：改为 `refreshAllMenuItems()` 主动递归遍历全部项（`applyMenuItemState` 统一设标题/勾选/使能），`validateMenuItem` 复用它。

### B7. 2026-08-30 Swift 里 AppKit 标准 selector 的写法

- `Selector(("undo:"))` 会触发 "use `#selector`" 警告；而 **`NSText` 并没有 `undo`/`redo`
  成员**（写成 `#selector(NSText.undo)` 直接编译错）。
- 正解：cut/copy/paste/delete/selectAll 用 `#selector(NSText.xxx(_:))`；undo/redo 用
  `NSSelectorFromString("undo:")`；窗口用
  `#selector(NSWindow.performMiniaturize/performZoom/performClose(_:))` +
  `#selector(NSApplication.arrangeInFront(_:))`（nil-target 走 responder chain）。

### B8. 2026-09-23 裸空格键等价会吞掉 Flutter 的「聚焦控件激活」

- **症状**：`Tab` 把焦点移到某个按钮后按空格，按钮没反应（**有曲目时**）；而无曲目时同一操作又能激活按钮 —— 行为随「有没有在播的歌」变化。
- **根因**：播放 ›「播放 / 暂停」用了 Apple Music 风格的裸空格（`keyEquivalentModifierMask = []`，见 B4）。`NSMenu` 的键等价匹配在 Flutter 引擎**之前**，只要该菜单项使能就把空格全部吃掉；而它的使能条件是 `hasTrack && !isTextEditing` —— 有曲目就吞，没曲目（项被禁用）才落给 Flutter。
- **修法**：把「Flutter 侧有控件持有键盘焦点」也算作让出理由 —— Dart `MenuService` 推 `hasKeyboardFocus`，Swift 侧 `applyMenuItemState` 的 `playPause` 分支加 `&& !menuState.hasKeyboardFocus`。
- ⚠️ **判定不能写成「`primaryFocus` 非空」**：路由自身的 `FocusScope`（`ModalRoute` 的 autofocus）在启动后就是 `primaryFocus`，那样写会让空格**永远**不再播放 / 暂停。必须要求「非 `FocusScopeNode` 的真实聚焦节点」，见 `lib/core/utils/keyboard_focus.dart` 的 `hasKeyboardFocus`。
- **护栏**：`test/keyboard_focus_test.dart`；`docs/UI-Rules.md` §10；`docs/Performance-Optimization.md` §9.2。

### B9. 2026-10-22 侧键 remap 工具发的是**合成滑动手势**，Dart 一条都收不到

- **现象**：装了 `SensibleSideButtons` 后按鼠标侧键，Flutter 侧**完全静音** ——
  `Listener` 没有 pointer 事件，`HardwareKeyboard` 也没有 key 事件；把该 app
  退出/禁用后，才收到 `PointerDownEvent.buttons = 0x08 / 0x10`。
- **根因**（读它源码确认）：它在 `CGEventTap` 上截 `otherMouseDown/Up`，**返回 NULL
  把原始按钮吞掉**，然后自己发一个**合成手势事件**（`CGEventType.gesture` + IOHID
  子类型 swipe `0x10`，方向写在 `ended` 帧的字段里）。那既不是按键也不是滚轮 ——
  Flutter 的 macOS embedder 只转发 key / mouse / scroll，手势事件进不了 Dart。
- **本项目结论：不支持，也不再验证**。要接住只能在 Runner 里加原生
  `NSEvent` 本地监听（`[.swipe, .gesture]`），为一个小众 remap 工具改原生层 +
  依赖“AppKit 会不会把它转成 `.swipe`”的未证实行为，不划算。工具开着时侧键在
  本 app 里就是没反应 —— 关掉它（原始按钮那条路可用）或让工具改发 ⌘`[`。
- **探查工具**：`test/demo/input_probe.dart`（`flutter run -d macos -t
  test/demo/input_probe.dart`）把 pointer / scroll / pan-zoom / key 全打出来 ——
  先看事件形状，再决定接哪一层。
- **通用教训**：某个输入在别的 app 里能用，**不代表框架收得到**。这类 remap 工具的
  输出至少有三种（原样透传按钮 / 合成快捷键 / 合成手势），而且**没有一个统一入口**；
  遇到“按了没反应”先用探针，别猜。

## C. Flutter 框架层

### C1. 2026-08-19 → 08-24 Flutter 3.47 macOS 全窗口闪烁（Intel 专属）

- **症状**：切到「专辑」tab + 页内滚动 → 界面异常闪烁；升级 Flutter 前（macOS 走 Skia）不闪。
- **根因**：**3.47 起 macOS 默认启用 Impeller**（此前 macOS 默认 Skia；SDF 在 macOS 上恒开），
  而本机是 **Intel Mac** —— 3.47 正在 phase out Intel，Impeller-Metal 在 Intel 上问题最多。
  专辑页（大量 `Image.file` + `frameBuilder` 的 `AnimatedOpacity` 淡入 + `ClipRRect` +
  elevation 阴影）是重灾区：纹理上传/合成时序变化 → 透明帧与淡入被频繁看到。
- **状态**：**未修**（等官方或改淡入实现）。提交 **flutter/flutter#191538**，官方在 Apple
  Silicon 上无法复现，已转 Impeller 团队。最小复现：`test/demo/impeller_flicker_repro.dart`
  （`flutter run -d macos -t test/demo/impeller_flicker_repro.dart`）。
- **基线事实**：本项目 `macos/Runner/Info.plist` 保留 **`FLTEnableImpeller=false`**（走 Skia）
  —— 所以在本项目里跑复现 demo **是 Skia，不会闪**，要在干净 `flutter create` 项目里跑。
- **验证方法**：临时删掉该 key 或加 `true`，`flutter run` 控制台会打印
  `Impeller rendering backend (Metal)`。

### C2. 2026-09-17 `ScrollPosition` 断言 `haveDimensions == (_lastMetrics != null)`

- **症状**：播放页「歌词 ↔ 播放队列」切换时偶发
  `scroll_position.dart:643 'haveDimensions == (_lastMetrics != null)': is not true.`
- **机制**：`_lastMetrics` **只在** `applyContentDimensions()` 内更新，而
  `ScrollPositionWithSingleContext.absorb()` 也会把 `_haveDimensions` 置 true ⇒ 存在
  「`haveDimensions==true` 但 `_lastMetrics==null`」的窗口，下一次 layout 断言失败。
  **含义：该断言 = 某个 ScrollPosition 在同一帧被重建/吸收，不是数据损坏。**
- **本项目触发路径**：`QueueView` 挂载时用上一版队列（65 首）的偏移去初始化只有 42 首的
  `ScrollController` → 偏移超范围纠正；同时点歌引发多次通知放大重建密度。
- **修法**：① 保存偏移时一并记队列长度（`queueScrollItemCount`），长度不一致就不恢复；
  ② `_scrollToCurrent()` / `_refreshFadeState()` 加 `position.hasContentDimensions` 护栏；
  ③ `PlayerService` 加载期间的多次 `notifyListeners()` 合并为一次。
- **护栏**：`docs/AudioEngine-Migration.md` 附录 D；`test/queue_locate_test.dart` 等。
- **通用教训**：跨会话的 UI 状态必须**绑定它所描述的内容**（长度 / id）；读
  `ScrollController.position` 的 metrics 前除了 `hasClients` 还要判 `hasContentDimensions`。

### C3. 2026-08-31 `TextField` 没有 `onKeyEvent`（3.47.2）

- **症状**：想在搜索框里拦 Esc 却无处挂。
- **修法**：外层包 `Focus(onKeyEvent:)`。`ToolbarSearchField` 改一次，四个页面全生效。

### C4. 2026-09-21 自拼行里的裸 `Icon` 不会被"染色"

- **症状**：设置 › 外观的「主题模式」「主题色」两行 leading 图标与邻行不同色（浅色下近纯黑、深色下偏白）。
- **根因**：`ListTile` 会给整行注入 `IconTheme`（M3 解析为 `scheme.onSurfaceVariant`），
  而**裸 `Icon` 拿不到**，退回 `ThemeData.iconTheme` —— 那是 **M2 遗留的固定纯黑/纯白**
  （`kDefaultIconDarkColor` / `kDefaultIconLightColor`）。
- **修法**：显式 `color: theme.colorScheme.onSurfaceVariant`。
- **护栏**：`test/settings_leading_icon_color_test.dart`（对比同页真 `ListTile` leading
  的实际渲染色）；`docs/UI-Rules.md` §9。
- **复发提示**：任何"不是 `ListTile` 但长得像设置行"的地方（自拼 `Row`）都要显式上色。

### C5. 2026-09-23 桌面端没有「退出键盘焦点」的路径（Tab 会变成死路）

- **症状**：按 `Tab` 后焦点环出现，之后**怎么都退不掉**：点鼠标没用、按 Esc 也没用；再按空格会激活那个（有时已经看不见的）聚焦按钮。
- **机制**（3.47 实测）：① Esc 的框架默认映射是 `DismissIntent`，而 `_DismissModalAction.isEnabled` 只看 `route.barrierDismissible` —— 普通页面路由为 false ⇒ 整条链 no-op；② Flutter 的 `InkWell` **点击既不请求焦点也不 unfocus**，所以点别处也不会摘掉旧焦点环；③ 3.47 的 `_HighlightModeManager.handlePointerEvent` 只处理 touch/stylus，**mouse/trackpad 直接落空** ⇒ 鼠标连"切回 touch 模式隐藏焦点环"都不会发生（macOS 的默认模式本来就是 traditional）。
- **修法**：`FocusManager.instance.addLateKeyEventHandler` 里 Esc → 取消焦点；根 Scaffold body 外包 `GestureDetector(behavior: translucent, onTap: 取消焦点)` 兜底「点空白」。
- ⚠️ 顺带结论：`IndexedStack` 已经给非选中子页包了 `ExcludeFocus`，保活页不会进 Tab 遍历，不需要额外处理。
- **护栏**：`lib/core/utils/keyboard_focus.dart`、`test/keyboard_focus_test.dart`、`docs/UI-Rules.md` §10。

### C6. 2026-09-23 根级 `Shortcuts(escape:)` 会劫持对话框的 Esc

- **症状**：为了给 Esc 加"取消焦点"，在 `MaterialApp.builder` 里包 `Shortcuts({escape: 自定义 Intent})` + `Actions` 后，**对话框按 Esc 关不掉了**。
- **根因**：`ShortcutManager` 命中后是从 **primaryFocus 的 context 向上**找 Action。`builder` 里的 `Shortcuts` 位于 `WidgetsApp` 默认映射与 Navigator 之间（比对话框那条 `DismissIntent` 更靠近焦点）⇒ 先被它匹配，随后又在 `builder` 自己的 `Actions` 里找到我们的 Action 并消费掉。
- **修法**：改用 `FocusManager.addLateKeyEventHandler` —— 它只在**没有任何控件 / 路由处理该键**时才运行，对话框 / `MenuAnchor` 菜单 / `ToolbarSearchField` 的 Esc 全部自然优先。
- **护栏**：`test/keyboard_focus_test.dart`（对话框与弹层菜单两例断言「处理器不被调用、弹层自行关闭」）。

### C7. 2026-10-01 弹出菜单在窗口底部会“从下沿滑上来”

- **症状**：播放条（窗口最底部）里的 `PopupMenuButton`，展开时不像“从按钮展开”，
  而是整张菜单从窗口下沿往上滑出来；菜单越高滑动越久，感觉“超过 300ms”。
- **根因**：`_PopupMenuRouteLayout.getPositionForChild` 的 y 来自 `y = position.top`，
  随后 `_fitInsideScreen` 在放不下时改成 `y = screen.bottom - 8 - childSize.height`
  —— 这里的 `childSize` 是**当帧动画中的尺寸**（高度 = 内容高 × `heightFactor`），
  于是每帧都有 `y + height ≡ screen.bottom - 8`：**底边被钉死、顶边随高度往上跑**。
  又因为 `clipBehavior` 默认 `Clip.none`，内容是整块被带着上移的（不是被裁剪揭示）。
  时长确实是 300ms（`_kMenuDuration`），但主导观感的滑动占 267ms —— 高度区间是
  `Interval(0, unit × 项数)`，`unit = 1/(项数 + 1.5)`，12 项时就是 `[0, 0.889]`。
- **修法**：换成自己控制生长锚点的实现 —— `MenuMorphRoute`
  （`lib/widgets/menu_morph_route.dart`）：位置只算一次、面板靠裁剪长大，
  内容在屏幕上不动。
- **顺带**：`package:animations` 的 `OpenContainer` 做不了这件事 —— 它的终点矩形
  写死是**整个 Navigator**（`open_container.dart`：`_rectTween.end = Offset.zero &
  navSize`），只适合“小控件 → 整页”的容器变换。
- **同一天补的第二个坑**：自己控制生长锚点后，向上生长只留了 8px 屏幕边距，
  而 macOS 那 52px 是**原生红绿灯**（标题栏透明、Flutter 视图铺满整窗）——
  面板装不下时顶边被钳到 y=8，正好钻进红绿灯底下。修法：扣
  `layoutConfig.menuTopInset`（macOS 52，其余 0），装不下就在面板内部滚动。

### C8. 2026-08-02 `ListTile` 选中色溢出 `ListView` 视口

- **症状**：滚动音乐库时，当前播放行的高亮背景画到列表视口之外，把相邻区域也染上色（issue #5）。
- **根因**：`ListTile.selectedTileColor` 不是 `ListTile` 自己画的，而是**最近的 `Material` 祖先**
  画的水墨层，而 `Material` 默认 `clipBehavior: Clip.none`。视口裁剪只能裁滚动内容树里的绘制，
  裁不到「视口之上那层 Material 画的高亮」。
- **修法**：给列表包一层自己的 `Material(type: MaterialType.transparency, clipBehavior:
  Clip.hardEdge)`，让高亮落在视口内的 Material 上（`lib/features/library/library_page.dart`
  的歌曲列表与文件夹列表两处，实际落点 `067ed90`）。上游同因：flutter/flutter#152832。
- **护栏**：视觉问题，无自动化测试；靠本条目 + 代码位置自查。
- **复发提示**：任何「Material 绘制的效果 + 可滚动视口」的组合（选中色、Ink 水波纹、`Card`
  阴影）都可能跑到视口外 —— 先查最近 `Material` 的 `clipBehavior`，而不是给 `ListView` 加裁剪。

### C9. 2026-08-11 网格 / `Sliver` 的 itemBuilder context 不能当菜单锚点

- **症状**：在播放列表网格卡片上长按，直接崩溃：
  `type 'RenderSliverGrid' is not a subtype of type 'RenderBox?'`（issue #12）。
- **根因**：锚点用 `context.findRenderObject() as RenderBox` 硬转，而 `SliverGrid` /
  `SliverList` 的 `itemBuilder` context 解析到的是 `RenderSliverGrid` / `RenderSliverList`，
  它们不是 `RenderBox`；卡片 / 行自己的 `Builder` context 才是。
- **修法**：锚点一律取自**卡片 / 行自己的 context**（`d506d5b` 先修；`2b3023c` 起统一走
  `MorphMenu` + `cardContext`）。公共换算 `overlayRectOf` 现在是 `is! RenderBox` 就返回 `null`，
  不再硬转（`lib/widgets/context_menu.dart`）。
- **护栏**：`test/context_menu_test.dart` 的「Sliver 的 itemBuilder context 拿不到行矩形 →
  返回 null（不抛类型错）」。
- **复发提示**：写新的列表 / 网格菜单时，`onTap` / `onLongPress` 闭包里用的 context 必须是
  itemBuilder 里再包一层 `Builder` 得到的那个，别把 sliver 的 context 传进菜单。

### C10. 2026-10-26 歌词滚动条在每次跟唱换行时闪一下

- **症状**：播放时每换一行，歌词右侧滚动条淡入再淡出；鼠标根本没碰歌词也会出现。
- **根因**：桌面端的 `MaterialScrollBehavior.buildScrollbar` 会给每个 `Scrollable` 套一层
  `Scrollbar`；`LyricView` 跟唱用程序化滚动，每次滚动都会触发 `Scrollbar` 的淡入动画。
  **只把 `thumbVisibility` 设为 `false` 不阻止这次淡入。**
- **修法**：`HoverScrollbarArea`（`lib/widgets/hover_scrollbar_area.dart`）把滑块可见性绑到
  区域悬停；不悬停时同时把 `ScrollbarThemeData.thumbColor` 设成透明，彻底遮掉程序化滚动
  触发的淡入（悬停时恢复主题色，拖拽不会被隐藏）。
- **护栏**：`docs/UI-Rules.md` §16；`test/lyrics_view_test.dart`「歌词滚动条只在鼠标位于
  歌词卡片上时显示」。
- **复发提示**：再遇到「程序化滚动导致滚动条闪现」，先看是不是只关了 `thumbVisibility`；
  颜色/透明度也要一起处理。

### C11. 2026-10-27 根 Scaffold 的底栏一挂一卸，body 里的页面会跳 64px

- **症状**：播放页展开动画结束的那一帧，整块内容（含底部控制带）往下跳约 64px；
  收起时反向跳一次。不是缓动问题，是**布局**跳。
- **根因**：`MaterialApp.builder` 里的 Navigator（所有路由）是根 `Scaffold` 的 `body`
  的孩子，body 高度 = 窗口高 − `bottomNavigationBar` 高。动画期间为了淡出内容把底栏
  留着 → 播放页按 `H−64` 布局；动画结束卸掉底栏 → body 长高 64 → 页面重新布局。
- **修法**：底栏的去留必须在**页面布局之前**定下来 —— 打开播放页时先让底栏内容淡出，
  再卸载底栏、再 `push`；收起动画跑完（`_playerReveal == 0`）才把底栏挂回。
- **护栏**：`docs/UI-Rules.md` §17「与迷你底栏的交接」。
- **复发提示**：任何"根 Scaffold 的底栏/`bottomNavigationBar` 在动画中途变了高度"的
  改动，都会让 body 里的页面重排；表现为"动画收尾时整体跳一下"，很容易误判成曲线问题。

### C12. 2026-10-27 `pushAndRemoveUntil` 会让新页滑入时露出主界面

- **症状**：从播放页点歌手/专辑/歌词设置，观感是"闪一下，然后目标页从右侧滑入"。
- **根因**：`pushAndRemoveUntil` 会**立刻**把下面那些路由从 Overlay 里移除；新页才滑到
  一半，底下已经不是播放页而是 shell 了。
- **修法**：要"替换但要保持垫底"就用 `pushReplacement`（等新页动画结束才移除旧页）。
  本项目最终改成**两段式**：先 `pop` 播放页（复用它自己的反向动画把卡片收回底栏），
  等路由真的销毁后再 `push`/`pushReplacement` 目标页 —— 这样"卡片收回"和"目标页进入"
  各自都是连续动画，中间不露底。
- **护栏**：`docs/UI-Rules.md` §17「从播放页跳别的页面 = 两段式」。
- **复发提示**：`pushReplacement` 与 `pushAndRemoveUntil` 的**移除时机**不同（前者动画后、
  后者立刻），凡是"替换页面"的动效都要先想清楚这个时机。

### C13. 2026-10-27 在 `initState` 里写被监听的 `ValueNotifier` 会撞 build

- **症状**：Debug 下抛 `setState() or markNeedsBuild() called during build`，指向某个
  `ValueListenableBuilder`。
- **根因**：路由在 push 过程中挂载（正处于 build 阶段），`initState` 里同步写一个被
  `ValueListenableBuilder` 监听着的 notifier，会立刻把那个 builder 标脏。
- **修法**：初始同步排到帧后（`addPostFrameCallback`），或干脆不写（值本来就对时不写）。
- **护栏**：`lib/app/router.dart` 的 `_ProgressMirror.initState`。
- **复发提示**：`didUpdateWidget`/`initState` 里做"同步到外部状态"的动作前，先问一句
  这个外部状态有没有人正在 build 时监听。

### C14. 2026-10-29 想「延后启动路由动画」时踩的两个 API 坑

- **症状**：写了个 `PageRoute` 子类，在 `didPush()` 里 `animation.stop()` 想把动画
  推迟到下一页首帧之后再 `forward()` —— 结果**静默无效**，动画照旧立刻开跑，日志里
  连一行都没打出来。
- **根因 1**：`TransitionRoute.animation` 返回的是 `_controller.view`（`Animation<double>`
  的视图），**不是** `AnimationController`。`animation is! AnimationController` 成立 →
  早退。正解是重写 `createAnimationController()`，在创建时把控制器本身存下来
  （`@protected`，正是给子类用的）。
- **根因 2**：`AnimationController.stop()` **不修改 status**，值停在中途但
  `isDismissed == false`。所以"要不要放行"的判断只能用 `value >= 1 || isAnimating`，
  用 `isDismissed` 会永远跳过。
- **另一个陷阱**：`ModalRoute.animation` 是 `ProxyAnimation(super.animation)`，路由处于
  offstage 时它的 parent 是 `kAlwaysCompleteAnimation` —— 在页面首帧读
  `animation.value` 可能读到 **1.0 / status=completed**。所以别用它当"动画是否走完"
  的信号，改用控制器自己的 `addStatusListener(completed)`。
- **护栏**：`lib/app/router.dart` 的 `_DeferredStartRoute`；`docs/Performance-Optimization.md`
  §1.7。
- **复发提示**：动 `TransitionRoute`/`PageRoute` 的动画时序前，先把 `routes.dart` 里
  `didPush` / `createAnimation` / `createAnimationController` 读一遍。

### C15. 2026-10-29 大面板上的 `FadeTransition`/`Opacity` 是 saveLayer，很贵

- **症状**：给播放页右侧歌词面板（约 1400×1200 物理像素）加 120ms 淡入，主观上"更
  顺"，实测**每帧 raster 20–25ms，挂载后多掉 8–13 帧**，比直接出现更卡。
- **根因**：`Opacity` 在 alpha < 1 时走 `saveLayer`（整块离屏合成）。面积越大越贵；
  本机（Skia + Intel iGPU）单次约 20ms。而且它掩盖不了前置的冻结帧 —— 冻结发生在
  opacity 还是 0 的时候，那时根本还没开始淡。
- **修法**：别用整块淡入。要柔和就用"纯色遮罩淡出"（一个 rect 的 alpha，成本可忽略），
  或者干脆不做过渡。
- **护栏**：`_RevealGate` 顶部的注释（`player_page.dart`）。
- **复发提示**：任何"给大子树加淡入来掩盖卡顿"的想法，先估一下
  `面积 × saveLayer` 的单价（本机 ≈ 20ms/1400×1200）。

## D. 领域事故索引（细节留在原文档）

| 症状 | 出处 |
| --- | --- |
| macOS 绿钮点击变全屏（应为最大化）；副作用：窗口再也无法全屏 | `UI-Rules.md` §2.1 |
| 无 ID3 的歌曲行内容整体偏上 8px | `UI-Rules.md` §6 |
| 当前播放高亮只在音乐库出现、播放/暂停图标不刷新 | `UI-Rules.md` §6.1 |
| 卡片 elevation 阴影在 Impeller 上有 ~20ms raster 尖峰 | `UI-Rules.md` §4.3 |
| HUD 与 SnackBar 抢位置 / 连按 ⌘↑ 攒一串提示 | `UI-Rules.md` §7 |
| 睡眠定时到点的反馈只有 SnackBar（HUD 在播放页被禁用） | `UI-Rules.md` §8 |
| Tab 焦点退不掉、空格激活「看不见的」聚焦按钮 | `UI-Rules.md` §10、本册 C5/B8 |
| 切歌提前量导致上一首尾部被截断；双实例掩盖间隙 | `AudioEngine-Migration.md` 附录 B/C |
| 歌词滚动条在跟唱换行时闪一下 | `UI-Rules.md` §16、本册 C10 |
| 播放页展开/收起收尾时整页跳 64px | `UI-Rules.md` §17、本册 C11 |
| 播放页展开动画第一次打开会顿（掉帧 14–16 帧） | `Performance-Optimization.md` §1.7、本册 C14/C15 |
| 从播放页跳转时"闪一下再滑入" | `UI-Rules.md` §17、本册 C12 |
| 镜像队列（引擎侧与 Dart 侧各持一份队列）必须互斥 | `AudioEngine-Migration.md` §0.4 |
| 引擎时序问题无法用假引擎单测覆盖 | `AudioEngine-Migration.md` §P2 |
| 变化检测移后台 isolate 时闭包捕获 UI 回调（unsendable） | `Performance-Optimization.md` §3.2 |
| 媒体控制下发的并发载体随引擎迁移变更，需代际守卫 | `Performance-Optimization.md` §5.6 |
| Windows C++/WinRT 缺 `winrt` 头时改走 cppwinrt / audio_service | `TODO.md` §3 |

**本册与代码注释的分工**：本册给的是排查路径与实证结论；改动点旁边那 1~2 行关键注释
仍要写（改代码的人看的是代码，不是文档）。
