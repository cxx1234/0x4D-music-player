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

## C. Flutter 框架层

### C1. 2026-08-19 → 08-24 Flutter 3.47 macOS 全窗口闪烁（Intel 专属）

- **症状**：切到「专辑」tab + 页内滚动 → 界面异常闪烁；升级 Flutter 前（macOS 走 Skia）不闪。
- **根因**：**3.47 起 macOS 默认启用 Impeller**（此前 macOS 默认 Skia；SDF 在 macOS 上恒开），
  而本机是 **Intel Mac** —— 3.47 正在 phase out Intel，Impeller-Metal 在 Intel 上问题最多。
  专辑页（大量 `Image.file` + `frameBuilder` 的 `AnimatedOpacity` 淡入 + `ClipRRect` +
  elevation 阴影）是重灾区：纹理上传/合成时序变化 → 透明帧与淡入被频繁看到。
- **状态**：**未修**（等官方或改淡入实现）。提交 **flutter/flutter#191538**，官方在 Apple
  Silicon 上无法复现，已转 Impeller 团队。最小复现：`test/impeller_flicker_repro.dart`
  （`flutter run -d macos -t test/impeller_flicker_repro.dart`）。
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

## D. 领域事故索引（细节留在原文档）

| 症状 | 出处 |
| --- | --- |
| macOS 绿钮点击变全屏（应为最大化）；副作用：窗口再也无法全屏 | `UI-Rules.md` §2.1 |
| 无 ID3 的歌曲行内容整体偏上 8px | `UI-Rules.md` §6 |
| 当前播放高亮只在音乐库出现、播放/暂停图标不刷新 | `UI-Rules.md` §6.1 |
| 卡片 elevation 阴影在 Impeller 上有 ~20ms raster 尖峰 | `UI-Rules.md` §4.3 |
| HUD 与 SnackBar 抢位置 / 连按 ⌘↑ 攒一串提示 | `UI-Rules.md` §7 |
| 睡眠定时到点的反馈只有 SnackBar（HUD 在播放页被禁用） | `UI-Rules.md` §8 |
| 切歌提前量导致上一首尾部被截断；双实例掩盖间隙 | `AudioEngine-Migration.md` 附录 B/C |
| 镜像队列（引擎侧与 Dart 侧各持一份队列）必须互斥 | `AudioEngine-Migration.md` §0.4 |
| 引擎时序问题无法用假引擎单测覆盖 | `AudioEngine-Migration.md` §P2 |
| 变化检测移后台 isolate 时闭包捕获 UI 回调（unsendable） | `Performance-Optimization.md` §3.2 |
| 媒体控制下发的并发载体随引擎迁移变更，需代际守卫 | `Performance-Optimization.md` §5.6 |
| Windows C++/WinRT 缺 `winrt` 头时改走 cppwinrt / audio_service | `TODO.md` §3 |

**本册与代码注释的分工**：本册给的是排查路径与实证结论；改动点旁边那 1~2 行关键注释
仍要写（改代码的人看的是代码，不是文档）。
