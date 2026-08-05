# UI Rules — 界面设计约束

本文件记录与 macOS 原生红绿灯/顶部区域、页面工具栏相关的设计约束，
供后续 UI 调整时遵循，避免破坏红绿灯定位与各页视觉一致性。

## 1. 布局配置（lib/core/constants/layout.dart）

- 结构：`PlatformLayoutConfig` 类（字段 `sidebarTopInset` / `sidebarWidth` /
  `pageToolbarHeight` / `pageToolbarTopInset` / `pageToolbarContentHeight`），通过全局 getter
  `layoutConfig` 按 `defaultTargetPlatform` 选择（macOS → `_macOS`，其余 → `_default`）。

| 字段 | macOS | 其他(Windows/Linux…) | 含义 |
|---|---|---|---|
| `sidebarTopInset` | 56 | 0 | 左侧边栏顶部预留（红绿灯区域；macOS 专属） |
| `sidebarWidth` | 100 | 80 | 左侧边栏（NavigationRail）宽度（macOS 让红绿灯组水平居中） |
| `pageToolbarHeight` | 112 | 112 | 页面标题工具栏总高 |
| `pageToolbarTopInset` | 32 | 32 | 工具栏顶部填充（替代被移除的全局顶栏高度） |
| `pageToolbarContentHeight` | 80 | 80 | 工具栏内容块高度（内容垂直居中） |
| `detailTopBarHeight` | 56 | 56 | 详情页顶栏总高 |
| `detailTopBarLeftInset` | 80 | 0 | 详情页左侧预留（macOS 让过红绿灯；Windows 不生效） |
| `playerTopBarTopReserve` | 45 | 0 | 播放页顶部红绿灯预留区（顶栏总高 = 56 控件区 + 本值） |

- 旧的**全局顶栏（TopBar）已于 2026-08-04 移除**，改为「页面避让」方案：
  - 左侧 NavigationRail 顶部预留 `layoutConfig.sidebarTopInset`（macOS=56）给红绿灯；
  - 右侧内容区各页使用统一高度的 `PageToolbar`（`lib/widgets/page_toolbar.dart`）。
- 传原生：Flutter 通过 **MethodChannel `flutter_music/window`**（方法 `setTopBarHeight`）
  在应用启动首帧后把 `layoutConfig.sidebarTopInset`（56）同步给 `MainFlutterWindow.swift`；
  **仅 macOS 会调用**（其他平台无 handler，避免 MissingPluginException 噪音）。
- **数值微调**：Windows 版调试时改 `_default`（或新增 Windows 专属配置）即可，无需动 UI 代码。

## 2. 红绿灯定位规则（macOS 原生层）

- 文件：`macos/Runner/MainFlutterWindow.swift` → `repositionTrafficLights()`
- 规则：
  - **垂直居中**：红绿灯中心距窗口顶 = `topBarHeight / 2`
  - **上 padding = 左 padding**：`left = (topBarHeight - 按钮高) / 2`
  - 按钮间保持系统默认间距。
- 因此红绿灯的最终位置完全由 `layoutConfig.sidebarTopInset` 决定。
  **调整该值即可让红绿灯与左侧栏等元素保持对齐**，无需改 Swift。

## 3. 左侧边栏（NavigationRail）对齐参考

- NavigationRail 宽度：macOS = `layoutConfig.sidebarWidth`（100），顶部外包 `Padding(top: layoutConfig.sidebarTopInset)`。
- 红绿灯中心对齐参考：`sidebarTopInset = 56`（按钮高≈14）时 上距=左距=21，
  红绿灯组中心 ≈ 50，与宽 100 的侧栏中心（50）对齐。

## 4. 页面工具栏（PageToolbar）

- 组件：`lib/widgets/page_toolbar.dart`，参数 `{title, subtitle?, actions?}`。
- 结构：总高 `layoutConfig.pageToolbarHeight`（112）= 顶部填充 `layoutConfig.pageToolbarTopInset`（32）
  + 内容块 `layoutConfig.pageToolbarContentHeight`（80，内容垂直居中）。
- 已覆盖：音乐库 / 专辑 / 歌手 / 播放列表 / 搜索 / 设置。
- **新页面接入规范**：顶部标题区一律用 `PageToolbar`，不要自行写 padding/Row，
  以保证各页工具栏高度与视觉完全一致。

### 4.1 详情页顶部栏（DetailTopBar）

- 组件：`lib/widgets/detail_top_bar.dart`，实现 `PreferredSizeWidget`，走 Scaffold `appBar:` 槽位（body 无需改动）。
- 结构：总高 `layoutConfig.detailTopBarHeight`（56）；左侧 `layoutConfig.detailTopBarLeftInset`（macOS=80 让过红绿灯，其余=0）；返回键紧凑（icon 18 / 命中区 24）；标题 `titleMedium` 左对齐。
- 已覆盖：专辑/歌手/播放列表详情、我的收藏。
- **规范**：二级详情页一律用 `DetailTopBar`；「播放全部」等大操作不放此栏（由页面内容区放置）。

### 4.2 详情页「播放全部」按钮（PlayAllButton）

- 组件：`lib/widgets/play_all_button.dart` —— 统一的**椭圆形文本按钮**（`FilledButton.icon` + `StadiumBorder`，▶ 播放全部）。
- 位置：放在**详情块信息文本下方**（封面右侧那一列，文本之下）；详情块底部外包 `Material(elevation: 3)` 产生**阴影**分隔列表区。
- 已用：专辑详情、播放列表详情、我的收藏（爱心占位详情块）、歌手「歌曲」区块标题右侧（同一组件）。

## 5. 二级页面待办

- 已用 `DetailTopBar` 完成避让（2026-08-04）：专辑/歌手/播放列表详情、我的收藏、播放列表（队列）全屏页。
- 播放页：保留其 `AppBar`，结构改为「顶部红绿灯预留 `playerTopBarTopReserve`（macOS 45）+ 下方 56 控件区」，控件固定在下方；标题字号与 `DetailTopBar` 一致（2026-08-05）。
- 仍待处理：歌词全屏页（`LyricsPage`，M3 `AppBar`≈56 会与红绿灯重叠）；其窄窗歌词展示方案后续另行讨论。
- 详情页按钮回归（2026-08-05）：专辑/播放列表/我的收藏 详情的「播放全部」统一用 `PlayAllButton` 椭圆形文本按钮（▶ 播放全部），置于**详情块信息文本下方**，详情块底部 Material 阴影分隔列表；播放列表详情的「添加歌曲/更多」放回 `DetailTopBar` actions；歌手详情用「歌曲」区块标题右侧的同一 `PlayAllButton`。收藏页 `_playAll` unused 告警已清零。
