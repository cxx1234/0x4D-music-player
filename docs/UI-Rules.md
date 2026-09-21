# UI Rules — 界面设计约束

> 跨领域 / 环境的坑（构建、macOS 原生层、Flutter 框架层）见 `Pitfalls.md`；
> 本文件只留界面约束。提交风格见 `Commit-Conventions.md`。

本文件记录与 macOS 原生红绿灯/顶部区域、页面工具栏相关的设计约束，
供后续 UI 调整时遵循，避免破坏红绿灯定位与各页视觉一致性。

## 1. 布局配置（lib/core/constants/layout.dart）

- 结构：`PlatformLayoutConfig` 类（字段 `sidebarTopInset` / `sidebarWidth` /
  `pageToolbarHeight` / `pageToolbarTopInset` / `pageToolbarContentHeight`），通过全局 getter
  `layoutConfig` 按 `defaultTargetPlatform` 选择（macOS → `_macOS`，其余 → `_default`）。

| 字段 | macOS | 其他(Windows/Linux…) | 含义 |
|---|---|---|---|
| `sidebarTopInset` | 52 | 0 | 左侧边栏顶部预留（红绿灯区域；macOS 专属） |
| `sidebarWidth` | 92 | 80 | 左侧边栏（NavigationRail）宽度（macOS 让红绿灯组水平居中） |
| `pageToolbarHeight` | 112 | 112 | 页面标题工具栏总高 |
| `pageToolbarTopInset` | 32 | 32 | 工具栏顶部填充（替代被移除的全局顶栏高度） |
| `pageToolbarContentHeight` | 80 | 80 | 工具栏内容块高度（内容垂直居中） |
| `detailTopBarHeight` | 52 | 56 | 详情页顶栏总高（macOS 与 unified 工具栏红绿灯中心对齐） |
| `detailTopBarLeftInset` | 95 | 0 | 详情页左侧预留（macOS 让过红绿灯；Windows 不生效） |
| `playerTopBarTopReserve` | 40 | 0 | 播放页顶部红绿灯预留区（顶栏总高 = 56 控件区 + 本值） |

- 旧的**全局顶栏（TopBar）已于 2026-08-04 移除**，改为「页面避让」方案：
  - 左侧 NavigationRail 顶部预留 `layoutConfig.sidebarTopInset`（macOS=52）给红绿灯；
  - 右侧内容区各页使用统一高度的 `PageToolbar`（`lib/widgets/page_toolbar.dart`）。
- **不再传原生**：`setTopBarHeight` 桥接已于 **2026-09-17 移除**（Dart 调用 + Swift no-op handler），
  红绿灯完全由 unified 工具栏原生定位，Dart 侧无需知道该高度。
  同通道（`com.jerryc.txvziwm/window`）的 `setTopBarGuard` / `setActionsWidth` 仍保留，用于顶栏双击拦截。
- **数值微调**：Windows 版调试时改 `_default`（或新增 Windows 专属配置）即可，无需动 UI 代码。

## 2. 红绿灯定位规则（macOS 原生层）

- **方案（2026-08-10 起）：unified 工具栏（macOS 11+）。**
  文件：`macos/Runner/MainFlutterWindow.swift` → 空 `NSToolbar` + `.unifiedTitleAndToolbar`，
  `toolbarStyle = .unified`。
- **红绿灯由 AppKit 原生垂直居中于工具栏行**（中心 ≈26，顶栏高 ≈52）：
  - 从启动起位置即稳定，**不再用 `setFrameOrigin` 与 AppKit 布局争夺**；
  - 之前 `setFrameOrigin` 方案因 AppKit 会在启动各布局时点反复覆盖按钮位置而不可靠。
- Flutter 侧按此对齐：`sidebarTopInset = detailTopBarHeight = 52`（= 2×26）。
- 部署目标为 **12.0**（`toolbarStyle` 需 11+；Xcode 工程当前设为 12.0）。

### 2.1 红绿灯绿钮：最大化而非全屏（2026-08-10）

- **行为**：绿钮点击 = **最大化窗口（zoom）**，不再进入全屏。
- **实现**（`MainFlutterWindow.swift`）：`collectionBehavior` 显式移除
  `.fullScreenPrimary` / `.fullScreenAuxiliary` 并插入 `.fullScreenNone`（三者互斥）。
  窗口不支持全屏 → AppKit 自动把绿钮降级为缩放按钮（`performZoom:`/`_setNeedsZoom:`）。
- **验证**：诊断输出 `zoom.action=_setNeedsZoom:`、`collection=512`（= `.fullScreenNone`）。
- ⚠️ 副作用：窗口从此**无法通过任何入口进入全屏**（含菜单/手势），如需全屏需改回
  `.fullScreenPrimary` 或改用「绿钮菜单选全屏」。

## 3. 左侧边栏（NavigationRail）对齐参考

- NavigationRail 宽度：macOS = `layoutConfig.sidebarWidth`（92），顶部外包 `Padding(top: layoutConfig.sidebarTopInset)`。
- 红绿灯由 unified 工具栏原生定位（中心 ≈26）；侧栏预留 `sidebarTopInset = 52` 使红绿灯在其中垂直居中。

## 4. 页面工具栏（PageToolbar）

- 组件：`lib/widgets/page_toolbar.dart`，参数 `{title, subtitle?, actions?}`。
- 结构：总高 `layoutConfig.pageToolbarHeight`（112）= 顶部填充 `layoutConfig.pageToolbarTopInset`（32）
  + 内容块 `layoutConfig.pageToolbarContentHeight`（80，内容垂直居中）。
- 已覆盖：音乐库 / 专辑 / 歌手 / 播放列表 / 设置。
- **新页面接入规范**：顶部标题区一律用 `PageToolbar`，不要自行写 padding/Row，
  以保证各页工具栏高度与视觉完全一致。

### 4.3 页面内嵌搜索（PageToolbar actions）

- **入口**：各功能页（音乐库/专辑/歌手/播放列表）标题栏 `PageToolbar.actions` 最前放搜索图标按钮（`Icons.search`，tooltip「搜索」）。设置页不做搜索。
- **进入**：点击后其余 actions 清空，仅保留 `ToolbarSearchField`（`lib/widgets/toolbar_search_field.dart`）——内部放大镜 + 有输入时清空按钮 + 外部关闭按钮；搜索框宽度弹性：最小 `minWidth`（默认 240），最大 = 窗口宽 × `maxWidthFactor`（默认 0.4，最大化窗口时变宽）。
- **过滤**：内存过滤，统一用 `lib/core/utils/search_util.dart` 的 `normalizeQuery`/`containsIgnoreCase`（纯函数，可单测）；查询为空显示全部内容。
- **匹配数**：搜索中 `PageToolbar.subtitle` 显示「匹配 N 首/张/位/个」。
- **无结果**：`Expanded(child: SearchEmptyState(query: …))`（`lib/widgets/search_empty_state.dart`）。
- **关闭**：清空输入回到全部内容（仍在搜索模式）；点关闭按钮退出搜索模式并恢复原 actions。
- **特例**：音乐库搜索时隐藏文件夹/扫描/沙箱横幅，仅显示歌曲结果；播放列表搜索时隐藏「我的收藏」卡片。
- **播放**：音乐库搜索结果的播放走 `LibraryViewModel.playSongsFromList(filtered, index)`，保证"下一首"限定在搜索结果内。

### 4.1 详情页顶部栏（DetailTopBar）

- 组件：`lib/widgets/detail_top_bar.dart`，实现 `PreferredSizeWidget`，走 Scaffold `appBar:` 槽位（body 无需改动）。
- 结构：总高 `layoutConfig.detailTopBarHeight`（macOS=52 与红绿灯中心对齐，其余=56）；左侧 `layoutConfig.detailTopBarLeftInset`（macOS=95 让过红绿灯，其余=0）；返回键与右侧功能按钮用 `IconButtonTheme` 统一（icon 22 / 命中区 36）；标题 `titleMedium` 左对齐，距左侧按钮约一个按钮宽度（32）。
- 已覆盖：专辑/歌手/播放列表详情、我的收藏。
- **规范**：二级详情页一律用 `DetailTopBar`；「播放全部」等大操作不放此栏（由页面内容区放置）。

### 4.2 详情页「播放全部」按钮（PlayAllButton）

- 组件：`lib/widgets/play_all_button.dart` —— 统一的**椭圆形文本按钮**（`FilledButton.icon` + `StadiumBorder`，▶ 播放全部）。
- 位置：放在**详情块信息文本下方**（封面右侧那一列，文本之下）；详情块（`DetailHeader`）底部用**底边线**（`Border(bottom: outlineVariant)`，`elevation: 0`）分隔列表区（2026-08-25 起弃用 elevation 阴影，见 4.3）。
- 已用：专辑详情、播放列表详情、我的收藏（爱心占位详情块）、歌手「歌曲」区块标题右侧（同一组件）。
- 空态禁用：播放列表详情 / 我的收藏在歌曲为空时传 `enabled: false`（`FilledButton` 原生禁用态），专辑/歌手因列表恒非空保持默认启用（2026-09-08）。

### 4.3 卡片表面（CardSurface）— 弃用 Card elevation 阴影

- 组件：`lib/widgets/card_surface.dart` —— `Container`（`surfaceContainerLow` 底色 + 圆角 12 + `boxShadow`）+ `Material(transparency)` + `InkWell`（水波保留）。
- **阴影**：`bottomDropShadow()` 3 条 `blurRadius: 0` 实线（偏移 (0,1)/(0,2)/(0,3)、alpha .10/.07/.04、颜色 `scheme.shadow`）。`blurRadius: 0` = 纯色填充，**不触发 Impeller 的 SDF blur** —— 弱 GPU / Intel 上近零 raster 开销（perf 验证：关 elevation 阴影从 ~20ms 尖峰回到 60fps）。
- **规范**：卡片一律用 `CardSurface`；**勿用 `Card(elevation:)`**（Material elevation 阴影在 Impeller macOS SDF 路径上开销高）。
- 已覆盖：专辑/播放列表网格（`CoverCard`）、播放列表「我的收藏」卡、音乐库文件夹行；`DetailHeader` 用 `elevation: 0` + 底边线分隔。
- 调参：改 `card_surface.dart` 一处即可（alpha / 偏移 / 底色）。

## 5. 二级页面待办

- 已用 `DetailTopBar` 完成避让（2026-08-04）：专辑/歌手/播放列表详情、我的收藏、播放列表（队列）全屏页。
- 播放页：保留其 `AppBar`，结构改为「顶部红绿灯预留 `playerTopBarTopReserve`（macOS 45）+ 下方 56 控件区」，控件固定在下方；标题字号与 `DetailTopBar` 一致（2026-08-05）。
- 仍待处理：歌词全屏页（`LyricsPage`，M3 `AppBar`≈56 会与红绿灯重叠）；其窄窗歌词展示方案后续另行讨论。(页面已完全重做，没有这个问题了)
- 详情页按钮回归（2026-08-05）：专辑/播放列表/我的收藏 详情的「播放全部」统一用 `PlayAllButton` 椭圆形文本按钮（▶ 播放全部），置于**详情块信息文本下方**；详情块底部**底边线**分隔列表（2026-08-25 起，弃用 Material 阴影，见 4.3）；播放列表详情的「添加歌曲/更多」放回 `DetailTopBar` actions；歌手详情用「歌曲」区块标题右侧的同一 `PlayAllButton`。收藏页 `_playAll` unused 告警已清零。

## 6. 列表行高与垂直居中（SongTile / ListItemTile）

- 组件：`lib/widgets/song_tile.dart`（歌曲行）、`lib/widgets/list_item_tile.dart`（歌手等实体行）。
- **固定行高 72**：各页列表用 `ListView(itemExtent: 72)`（音乐库/歌手/队列 `_kQueueTileExtent`），
  `IndexScrollbar` 的 `itemExtent` 也按 72 换算滚动位置 —— 三者必须与
  `SongTile.kRowHeight`（72）一致。
- ⚠️ **必须在 `ListTile` 上显式写 `minTileHeight: SongTile.kRowHeight`**：
  两个组件都把「副标题」放进 `title` 的 `Column` 里，`ListTile.subtitle` 恒为 null，
  于是 ListTile 始终按**单行**模式（默认行高 56）计算 `titleY`/`leadingY` 并居中。
  外层 `itemExtent: 72` 把行高紧约束成 72 后，内容整体偏上 `(72-56)/2 = 8px`
  —— 表现为**没有 ID3（无歌手/专辑）的歌曲行内容与封面整体偏上**（2026-09-17 修复）。
- **回归测试**：`test/song_tile_layout_test.dart`（真实 `itemExtent: 72` 列表里断言
  标题/行首槽位/封面相对行中心居中，宽度 0.5px 内）。
- 注意：`itemExtent` 是硬约束，超大字号（系统文字缩放）下行内容高于 72 时仍会被挤，
  属固定行高列表的固有取舍。

### 6.1 当前播放高亮（2026-09-18）

- 高亮契约（`SongTile`）：
  - `isCurrentSong` → 底色（`selectedTileColor` = `primary` 10%）+ 标题主色加粗 +
    副标题/时长主色；
  - `isPlaying` → 封面「播放中」遮罩（变暗 + 白色跳动均衡器）与行尾
    `volume_up_rounded` / `pause_rounded`。**仅在 `isCurrentSong` 为 true 时生效**，
    调用方误传不会点亮别的行。
- ⚠️ **凡反映播放态的列表都必须订阅 `player.uiListenable`**（切歌 + 播放态 + 队列，
  不含 ~200ms 的进度）。只订 `currentSongNotifier` 时播放/暂停翻转不触发重建，行内
  图标会停在旧状态（2026-09-18 修复：专辑/歌手/收藏/播放列表详情原为此种情况，
  且 `isPlaying` 只有音乐库传了）。
- 调用点共 6 处：音乐库 / 专辑详情 / 歌手详情 / 我的收藏 / 播放列表详情 / 播放队列。
  队列用 leading 的播放箭头指示当前项，并传 `showCurrentIndicator: false` 隐藏行尾图标。
- **歌曲列表左右内边距统一 `EdgeInsets.fromLTRB(16, 4, 16, 16)`**：否则当前播放行的
  高亮底色条宽度不一致（歌手详情原为 24/0/8/16）。队列保持通栏（右栏面板，故意不加）。
- 行尾间距：播放态图标 → 时长文本 `right: 12`（原 8，读起来像一体），时长 → 更多菜单 `6`。
- 回归测试：`test/song_tile_current_state_test.dart`（7 例，覆盖上述契约与两种 leading）。

## 7. 外部播放操作的反馈（HUD / 控件脉冲，2026-09-18）

- **入口**：macOS 原生菜单（`menu_service.dart`）与媒体键 / 系统「正在播放」面板
  （`media_control_service.dart`）。两者都**不直接调 `PlayerService`**，统一经
  `ServiceLocator.feedback`（`PlaybackFeedbackService`）转发 —— 文案与反馈只有一份。
- **范围**：仅 音量 / 切歌 / 播放暂停 / 停止。循环模式、随机不纳入（它们在界面上的图标本身
  就是状态，再叠提示只是噪音）；「停止」只有 HUD——应用里没有停止按钮可脉冲，
  原生菜单项会自己高亮。
- **两条反馈通道**：
  - **HUD**（`lib/widgets/hud_overlay.dart`）：底部居中，距窗口底
    `HudOverlay.kBottomInset = 124`（底栏 64 + SnackBar 单行 48 + 间隙 12），
    **必须整条让开 SnackBar**；挂根 Overlay 的**第二条 entry**（比 Scaffold 晚绘制，
    天然在最上层），并 `IgnorePointer` 不吃点击。
  - **控件脉冲**（`lib/widgets/control_pulse.dart`）：播放页 `PlayerControls` 与
    底栏 `NowPlayingBar` 的对应按钮亮 180ms。**播放页没有 HUD**，脉冲是那里的
    唯一反馈。
- **播放页禁用 HUD**：`app.dart` 用 `_showBar`（false = 播放页在最上层）作 `enabled`；
  禁用期间到达的消息**就地丢弃**，否则离开播放页时会延迟弹出。
- **文案**：结果态（播放中 / 已暂停）、`下一首 · 歌名`、`上一首 · 歌名`；
  队尾 `已是最后一首`、队首 `已是第一首`、无曲 `没有播放中的歌曲`。
  判定「是否真的切了」= 索引或歌曲 id 变化 **或** 列表循环（单曲队列绕回同一首也算）。
- ⚠️ **不要用 SnackBar 做这类反馈**：它是队列式的（连按 ⌘↑ 会攒一串）、底部锚定、
  带 action 语义，定位是「通知」（播放错误、导入导出结果）。HUD 是「操作回显」，
  连续操作必须原地更新。
- 回归测试：`test/hud_service_test.dart`（4）、`test/hud_overlay_test.dart`（5）、
  `test/playback_feedback_test.dart`（8）、`test/control_pulse_test.dart`（4）。

## 8. 睡眠定时入口（PlayerBar 左侧，2026-09-19）

- **位置**：播放页底部条 `PlayerBar` 的**左侧槽位**——那是原先为「让控制按钮严格居中」
  留的与音量块等宽的占位（`_kVolumeBlockWidth = 144`），现在放月亮按钮，宽度不变，
  控制按钮仍然居中。
- **控件**：`SleepTimerButton`（`lib/widgets/sleep_timer_button.dart`）——计时器图标；
  激活时图标转主题色并显示剩余时间（`M:SS`，满 1 小时 `H:MM:SS`）。
  窄窗口（`compact`）只留图标，避免和音量块抢宽度。
- **悬停形状必须显式给**：child 模式的 `PopupMenuButton` 内部是裸 `InkWell`，
  不传 `borderRadius` 时高亮会被裁成方块（icon 模式走 `IconButton` 才自带圆角）。
  这里是固定高 36 + `BorderRadius.all(Radius.circular(18))` → 图标态 36×36 正圆，
  显示剩余时间时自然变成胶囊。
- **弹出菜单动画保持 Material 默认**：`PopupMenuRoute` 默认 300ms + `Curves.linear`
  （`_kMenuDuration`）。2026-09-19 曾用 `popUpAnimationStyle` 提速到 140ms 后按用户
  反馈**回退默认**——不要再改；`PopupMenuThemeData` 也没有这个字段，无法全局设置。
- **菜单**：5/10/15/30/45/60/90 分钟 → 分隔线 → 「播完当前曲目」「播完当前播放列表」
  → 激活时再加「取消定时（剩余 M:SS）」。勾选项用 `CheckedPopupMenuItem`
  （`PopupMenuItem` 在本 Flutter 版本已无 `checked` 参数）。
- **到点反馈走 SnackBar，不走 HUD**：`SleepTimerService.notice` →
  `app.dart` 的 `_PlayerNoticeConsumer`（与播放错误同一个消费器）。
  理由见 §7——播放页禁用 HUD，而睡眠定时最常见的到点场景恰恰是"用户已经睡了、
  任意页面都可能"，只在播放条上留下状态变化是不够的。
- 逻辑分层：`SleepTimerService` 不依赖 `ServiceLocator`（只依赖 `PlayerService`），
  入口按钮与提示都是它的视图；回归测试 `test/sleep_timer_test.dart`。
- **macOS 菜单栏入口**：播放 ›「睡眠定时」子菜单（`AppDelegate.swift`
  `sleepTimerSubmenuItem()`）——5/10/15/30/45/60/90 分钟 + 播完当前曲目 +
  播完当前播放列表 + 取消定时。⚠️ 预设列表与 `SleepTimerButton.presets` 是**两处
  各一份**（原生读不到 Dart 常量），改一处要记得改另一处。
  - 勾选/使能靠 `MenuService` 推送的 `sleepTimerMode`（off/duration/endOfTrack/
    endOfQueue）+ `sleepTimerMinutes`（**当初设定**的分钟数，来自
    `SleepTimerState.requested`）；倒计时每秒都在变但这两个字段不变，所以不会每秒
    推一次通道。「取消定时」只在有定时时可点。
  - 动作经 `PlaybackFeedbackService`（外部操作统一出口）执行 + 发 HUD 回显：
    非播放页没有那个定时按钮，HUD 是唯一反馈。
- **设置项**：设置 › 播放设置 ›「睡眠定时先播完当前曲」（`sleepTimerFinishCurrentTrack`，
  默认关）。它把**倒计时**到点的行为从"立即淡出暂停"改成"转入 `endOfTrack`、等这一首
  播完再停"；真值经回调注入（`SleepTimerService.waitForTrackEnd`）现读，改完立即生效。
  这两种到点各弹一条 SnackBar：切换等待时 `睡眠定时到点，播完当前曲目后停止`，
  真正停下时 `睡眠定时结束，已停止播放` / `睡眠定时结束，已暂停`（前一条也为了
  解释"倒计时为什么突然消失"）。

## 9. 列表行 leading 图标着色（2026-09-21）

- **`ListTile` 的 leading / trailing 图标不用手动上色**：M3 会把整行内容包进
  `IconTheme`（`iconColor = colorScheme.onSurfaceVariant`，见 `list_tile.dart` 的
  `_LisTileDefaultsM3`），裸 `Icon` 自动跟着主题走中性灰。
- ⚠️ **自拼 `Row` 里的裸 `Icon` 拿不到这层注入**，会退回 `ThemeData.iconTheme` 的
  默认值——那是 **M2 遗留的固定纯黑 / 纯白**（`kDefaultIconDarkColor` /
  `kDefaultIconLightColor`），既不跟随明暗也不跟随主题色，肉眼比邻行图标更黑 / 更白。
  **必须显式 `color: theme.colorScheme.onSurfaceVariant`**（同类写法：
  `library_page.dart` 排序菜单的 `PopupMenuButton.iconColor`、
  `playlist_page.dart` / `playlist_detail_page.dart`）。
- **「不染色」的含义是不跟随 accent 色，不是不设颜色**——`onSurfaceVariant` 本身就是
  中性灰。已按此法修：设置 › 外观的「主题模式」（太阳 / 月亮，仍随明暗切换图标）
  与「主题色」（`palette_outlined`）两行。
- 回归测试：`test/settings_leading_icon_color_test.dart`（2 例，明暗各一）——用
  `Icon.color ?? IconTheme.of(context).color` 取实际渲染色，与同页 `ListTile`
  leading 图标（`Icons.replay_rounded`）对比，日后新增自拼行忘上色会直接失败。
