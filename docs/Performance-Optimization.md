# 性能与待优化项清单

> 删除线 = 已完成；其余为待办。⛔=已失效/不再适用；🆕=2026-09-17 审计新增。
> 🆕²=2026-09-22 审查新增（针对 0.2.4–0.2.6 的睡眠定时 / 通知 / HUD / 原生菜单）。
> 🆕³=2026-09-23 新增（键盘焦点 / 空格归属，见 §10）。
> 🆕⁴=2026-10-29 新增（播放页展开动画实测，见 §1.7）。
> 🆕⁵=2026-11-07 复核新增（0.4.x：i18n / 播放页展开 / 歌词 / 变形菜单，见 §12）。
> 最后更新：2026-11-07（新增 §12 复核与 §13 遗留项盘点；待办项已从「行号」改成
> 「文件 + 符号」定位，不再随代码漂移）
> 最后更新：2026-10-29（新增 §1.7：展开动画掉帧的实测、修法与残留项；其余行号按 2026-09-17 代码）

## 1. 渲染 / UI 类

- ~~P1 高频重建削减（播放页局部化、`uiListenable`、进度条自订阅、`PlayQueue.songs` 缓存视图）~~
- ~~P2 封面降采样解码（`cacheWidth` + `gaplessPlayback`）~~
- ~~1.1 搜索过滤结果缓存（`QueryFilterCache`，四页过滤 getter 接入）~~
- ~~1.2 关键区域加 `RepaintBoundary`（歌词区 / 播放页封面信息卡 / `CoverCard` 网格；不含长列表逐行）~~
- ~~1.3 歌手详情定向查专辑（`getAlbumsByIds` 空集合短路，替代全表拉取）~~
- ~~1.4 `NowPlayingBar` 订阅收窄 + 底栏背景进度填充（可开关：设置 › 外观）~~
- ~~用户自规划：全局底栏「按播放进度填充」效果（整体背景色从左向右，可开关）~~
- ~~L3 收藏跨视图不一致（当前曲改走 `toggleFavoriteForCurrent`，队列快照同步；2026-09-17 ✅）~~
- ~~U3 `SongTile` build 内真构建菜单（改判 `menuBuilder != null`，菜单仍在 `itemBuilder` 内按需构建；2026-09-17 ✅）~~
- ~~U5 非选中页动画空转（`shell_page` 给 IndexedStack 子项包 `TickerMode(enabled: active)`；2026-09-17 ✅）~~
- ~~L1/L2 await 后未复查 mounted（`queue_view` 批量删除、`library_page` 导入/移除/重授权；2026-09-17 ✅）~~
- ~~U1 进度条拖动每 tick seek（改为拖动预览 + `onChangeEnd` 提交一次，左侧时间同步预览；2026-09-17 ✅）~~
- ~~U2 音乐库播放态整页 setState（改为 VM 暴露 `playerUiListenable`，列表局部重建；2026-09-17 ✅）~~
- ~~U4 菜单动作后无条件整表重查（四个动作都不改变列表内容，已去掉重查；2026-09-17 ✅）~~
- ~~L4 设置页缓存大小保活不刷新（新增 `active` + `didUpdateWidget` 重读；2026-09-17 ✅）~~

### 1.5 🆕² 底栏进度填充层每 ~200ms 重建一次 widget 子树
- 位置：`_PlaybackFill.build()`（`lib/features/shell/now_playing_bar.dart`，订整个 `PlayerService`）。
- 现状：绘制已用 `RepaintBoundary` 隔离（1.4 ✅），但每次 position tick 仍走一遍 build（`FractionallySizedBox` + `ColoredBox`），只是重建范围小。
- 改法：暴露一个只带 progress 的 `ValueNotifier<double>`（或让填充层订它），让 build 只在百分比变化时发生。

### 1.6 🆕² 睡眠定时按钮的刷新粒度与菜单勾选
- **2026-11-07 复核**：③ **已解决** —— 2026-10-01 起菜单改为容器变换（`MorphMenuEntry.checkable`），预设项有勾选态；① 仍订 `state` 每秒重建（开销可忽略）；② 变形菜单仍是一次性构建，打开期间剩余时间不刷新（设计限制）。
- 位置：`sleep_timer_button.dart`（`ValueListenableBuilder` 订 `state`）。
- 剩余改法（低）：① 只在剩余时间的显示文本变化时更新；② 若要实时倒计时，面板需自己持 `ValueListenableBuilder`，与容器变换「打开前算高」冲突，收益低。

### 1.7 🆕⁴ 播放页展开动画：实测、修法与残留（2026-10-29）

**症状**：冷启动后第一次点迷你底栏进「正在播放」会明显顿一下，之后同样动效明显更顺。

**测量方法**（很轻，值得复发时照抄）：`SchedulerBinding.addTimingsCallback` 把
`build+raster ≥ 16ms` 的帧写进应用日志（Release 下也能看，DevTools 连不上 AOT），
交互入口用临时 `MARK` 打点；再用 `--dart-define=AUTO_OPEN_PLAYER_SECONDS=6` 自动
触发播放页展开，保证多轮可比。**测完把探针删掉**，它不是常驻设施。

本机基线（2018 15" Intel MBP，UHD 630 + Radeon 560X，Retina 2x，Skia）：

| 指标 | 修前 | 修后 |
| --- | --- | --- |
| 进播放页首帧 ui | 78–88ms | **22–23ms** |
| 展开动画期间 ≥16ms 帧数 | 14–16 | **0** |
| 展开动画期间 raster 中位 | 20ms | 全部 <16ms |
| 挂载歌词栏那一帧 | ui 73–75 + raster 34 | ui 62–65 + raster 40–44（一次性） |

**根因（三条，互不相同）**

1. `TransitionRoute.didPush` 在同一帧 `forward()`，而 `AnimationController` 按真实
   时间推进 —— 页面 build+layout 花 80ms，等这帧画完进度已经跳到 ~20%，**前半段
   动画被整段吞掉**，观感是「卡一下再从中间开始」。
2. 页面子树没有合成层：`BottomBarReveal` 每帧 `Transform.scale` + 圆角裁剪，整页
   每帧重新光栅化（Retina 全窗 ≈ 520 万像素）。
3. 右栏（歌词/队列）建一次 70ms 上下，且**每次打开都重做**：`LyricViewSession` 是
   State 级的，`LyricLayout.compute` 会把整篇每一行都 `TextPainter.layout()` 一次
   （主行 + 翻译行各一个）。

**修法（已落地）**

- `AppRouter.bottomUpRoute` 换 `_DeferredStartRoute`：`didPush` 里先 `stop(canceled: false)`
  控制器，`addPostFrameCallback` 里再 `forward()`，进度从 0 连续走；同时暴露
  `ValueNotifier<bool> revealed`（`AnimationStatus.completed` 时置 true）。
- `BottomBarReveal` 的 `Transform.scale` 下、`_lift` 的 `Transform.translate` 下各加
  一层 `RepaintBoundary`（**两层都要**：位移每帧变，只加外层会被内层 `markNeedsPaint`
  重新标脏）。raster 中位 28.6 → 19.9ms。
- `_RevealGate`（`player_page.dart`）：条件 = `revealed && 歌词就绪`，只拦**第一次**
  揭开（之后常驻，否则收起时右半边会空）。就绪判定还要处理**前奏期**：
  `activeLineIndex` 为 null 且位置早于第一行时间戳时，顶部本就正确，不能因此不挂。

**被否掉的（都实测过，别再回头试）**

- 挂载时加 120ms `FadeTransition` 淡入：`Opacity` 在 <1 时是 `saveLayer`，面板
  ~1400×1200 每帧重合成 20–25ms，实测挂载后多掉 8–13 帧，且掩盖不了前置的冻结
  （冻结发生在 opacity 还是 0 的时候）。已回退并在代码注释里写明。
- 切独显：同一二进制、同一 harness，raster 只从 41.4 降到 36.5ms（≈12%，还在轮间
  噪声内），`ui` 完全不变。**raster 的大头在 Skia 的 raster 线程 CPU（命令回放 /
  文字 / saveLayer / 裁剪），不是 GPU 填充率**；这条也顺便否掉了"换 Impeller 能治
  这 40ms"的期待（Impeller 主要治着色器编译尖峰）。

**残留（未修，需上游改动）**

- 挂载歌词栏仍是一帧约 105ms：ui 62–65（全量文字排版）+ raster 40–44（首绘）。
  消它只有两条路，见 §1.7.1。
- 稳态：歌词可见且跟唱时每帧 raster 18–30ms（整块歌词区重绘）。

#### 1.7.1 下一步：歌词布局的懒/缓存化（未做）

- **A. 布局常驻**：让 `LyricsView` 的 State（带 `LyricLayout`）不随播放页 pop 销毁
  —— 重开 0ms，但切歌/切翻译/缩放窗口仍要重排；要处理 State 归属与隐藏时停 ticker
  （包已尊重 `TickerMode`）。
- **B. 上游/fork**：`LyricLayout` 只量可见行（其余按估算高度），并按
  `(documentRevision, resolvedStyle, viewSize)` 缓存 —— 每次几 ms，且同时覆盖重开、
  切歌、切翻译、resize。项目里 `audio_metadata_reader` 已有 fork 先例。
- **C. 稳态重绘**：把 `LyricViewport.paint` 拆成「静态行层 + 活动行层」，让卡拉OK
  填充只重绘活动行（约总面积 1/8）：20–30ms → 3–5ms。
- **2026-11-07 复核**：仍未做。建议**先做 B**（一次覆盖重开 / 切歌 / 切翻译 / resize），
  A 只解决重开；建议顺序见 §12.11。

---

## 2. 启动 / 数据层类

- ~~P3 DB schema v6（7 索引）+ WAL + 队列恢复批量查询~~
- ~~2.9 扫描根读取失败时整根被误标不可用（改为只用成功读取的根 `okRoots` 做 diff；2026-09-17 ✅）~~
- ~~2.10 文件夹路径 `LIKE '$root/%'` 未转义（改「SQL 粗筛 + Dart 精确判定」，新增 `utils/path_under_root.dart`；`deleteFolderSongs` 改分块 `isIn` 删除；2026-09-17 ✅）~~

### 2.1 启动路径串行阻塞
- 位置：`ServiceLocator._doInitialize()`（版本号 `_loadAppVersion()` 在关键路径最前）。
- 改法：`Future.wait` 并行独立步骤（settings/DB 开库、backfill、restoreQueue、sandbox）；版本号读取移出关键路径。

### 2.2 每次启动全盘遍历阻塞首屏
- 位置：`LibraryViewModel.initialize()`（`_quickSync` 在 `_loadSongs` 之前；文件在 `lib/features/library/`）。
- 改法：先加载歌曲列表再后台 quickSync。

### 2.3 数据库跑主 isolate
- 位置：`AppDatabase.create()`（`NativeDatabase` 在主 isolate）。
- 前置：WAL 已开。风险：中（需全量测试 + 真实库验证）。
- 改法：`createInBackground`/`readPool`。

### 2.4 `getExistingFileStats` 拉全行
- 位置：`AppDatabase.getExistingFileStats()`。
- 改法：投影 `file_path/last_modified_ms/file_size` 三列。

### 2.5 `backfillSortKeys` 每次启动 3 次无索引全表扫
- 位置：`SongRepository.backfillSortKeys()`（已无全表 UPDATE，但仍未短路；现在只查 `sort_key IS NULL` 的行）。
- 改法：先 `COUNT(*) WHERE sort_key IS NULL` 短路。

### 2.6 watch 流全是死代码
- 位置：`AppDatabase` 里的 6 个 `watch()` 流（零调用；`song_repository` 已无引用）。
- 改法：删除，或改用 drift 流式更新替代手动 reload。

### 2.7 `getAllFilePaths` 拉全行（`getFolderFilePaths` 已修）
- 位置：`AppDatabase.getAllFilePaths()`（仍 `select(songs)` 物化全列）；调用点 `LibraryViewModel._syncQueueWithLibrary()`。
- 已修：`getFolderFilePaths` 改为 `selectOnly` 投影 + Dart 精确过滤（见 2.10，2026-09-17 ✅）。
- 改法（剩余）：`getAllFilePaths` 改 `selectOnly(songs.filePath)`；多根合并为一次查询。

### 2.8 dateAdded / playCount / year 排序无复合索引
- 位置：`AppDatabase._createIndexes()` + 歌曲排序构造（schema 仍 v6、7 索引）。
- 改法：按需补 `(is_available,date_added)` / `(is_available,play_count)`。

### 2.11 🆕 `resetInitialization()` 重试不释放旧实例（中）
- 位置：`ServiceLocator.resetInitialization()`（只置空 `_initialization`，不 dispose 已建服务：PlayerService / MediaControlService / LyricsViewModel）。
- 后果：幽灵 AudioEngine + 重复歌词订阅。
- 改法：reset 前 dispose 已建服务，或仅在未创建时允许 reset。

### 2.12 🆕 设置页「强制刷新」在扫描中被静默忽略（中）
- 位置：`LibraryViewModel` 的扫描单飞守卫（只 `AppLogger.warning`，UI 无反馈）+ 设置页「强制刷新」入口。
- 改法：给 SnackBar 提示或排队执行。

## 3. 扫描 / 元数据类

- ~~3.1 元数据解析并发 + Isolate（受限并发 worker 池 + 100ms 进度节流）~~
- ~~3.2 变化检测移后台 isolate（`detectChangedFiles` + `Isolate.run`；⚠️ 闭包勿捕获 UI 回调，防 unsendable）~~
- ~~3.3 扫描事务查询去重（artist/album 批量缓存 + dateAdded 批量）~~
- ~~3.4 文件夹并行遍历（`Future.wait`）~~
- ~~3.9 扫描单飞守卫（`_scanInProgress` 覆盖 startScan/forceScan/rescan/quickSync——`library_view_model.dart:44/257/296`；2026-09-08 ✅）~~
- ~~3.10 force 清幽灵误删仍在文件（磁盘路径 `p.normalize` 归一化 + `File.existsSync()` 二次确认，统一复用 `isUnderRootPath`；2026-09-17 ✅）~~

### 3.5 待办（行号按 2026-09-17）
- 3.5 扫描无条件拉 `existingStamps`（全库映射；force 与非更新分支都白查）— `LibraryScannerService.scanFolders()` 的 Phase 3b。移进变化检测分支并按根限定。
- 3.6 每次 quickSync 都跑 `cleanupOrphans` + 孤儿封面清理（无 mode 判断）— `LibraryScannerService.scanFolders()` 的 Phase 3d（`_quickSync` 也走它）；每次启动 = 2 次全表扫 + `covers/` 全列（`AlbumArtCacheService`）。仅确有增删改/恢复才清；quick 跳过。
- 3.7 `cleanupOrphans` 3 段全表扫 + `isIn` 删除 — `AppDatabase.cleanupOrphans()`。改 `DELETE … WHERE NOT EXISTS`。
- 3.8 `restoreFiles` 逐文件 UPDATE — `SongRepository.restoreFiles()` + `AppDatabase.markAsAvailable()`。仿 `markMissingFiles` 用 `isIn` 批量。

### 3.11 🆕 `restoredFiles` 在主 isolate 逐路径 `existsSync`
- 位置：`LibraryScannerService` 的 `restoredFiles` 计算（主 isolate 逐路径 `existsSync`），抵消 3.2 把 `statSync` 移入 isolate 的收益。
- 改法：并入 `_detectChangedInIsolate` 或复用目录收集结果。

---

## 4. 后台 / 服务类

- ~~4.1 每秒重读封面 + 整包 push（拆为「全量元数据推送」与新增的 `updateElapsed` 轻量进度通道；Swift 侧只改 elapsed/rate，不再每秒 `NSImage` 重解码；2026-09-17 ✅）~~
- ~~4.4 媒体键 EventChannel `onError` 静默（改为 `AppLogger.warning`；2026-09-17 ✅）~~
- ~~4.5 folder watcher 无防抖 + 扫描期并发触发（已改 500ms 去抖批量 + `suspend()` 扫描期缓冲 + `resumeAfterScan`；`folder_watcher_service.dart:56/127/181`，2026-09-08 ✅）~~
- ~~4.6 watcher 残留问题（`suspend()` 改为 async 并等待在途 flush；跳过项按「事件时间 vs 扫描开始」过滤（force 扫描不再吞掉扫描期间的编辑）；扫描期间已落库的变更在 resume 时补发汇总通知；remove 落库前校验文件确实已不在；2026-09-17 ✅）~~

### 4.2 日志每行 flush
- 位置：`AppLogger` 的写入路径（每条日志结束都 `await _sink.flush()`）。
- 改法：批量缓冲 + 周期 flush（保持崩溃前落盘语义）。

### 4.3 媒体键操作 fire-and-forget 未串行
- 位置：`MediaControlService._handleEvent()`。⚠️ 原依据「与扫描 `_rebuildSequence` 并发」已失效（该方法随引擎迁移删除）；现并发载体为 `PlayerService._loadCurrent`——已加代际守卫（5.6 ✅），剩余风险为连击时的重复下发。
- 改法：给引擎操作加操作串行/统一入口。

### 4.7 🆕² ~~媒体控制 `setup()` 失败会把「媒体键不可用」升级成整屏启动失败页~~ ✅（2026-09-29）
- **已修**：`initialize()` 里只包住 `setup()` 一步 try/catch + `AppLogger.warning`，其余订阅照常建立。
- 位置：`media_control_service.dart:48`（`await _controls.setup()` 无 try/catch）→ 冒泡到 `app.dart:47-58` 的 `ServiceLocator.initialize()` catch → `StartupErrorPage`（fatal）。
- 背景：sandbox / menu / media_controls 三个通道都在同一次原生 `applicationDidFinishLaunching` 里注册，Dart 侧初始化先跑就会 `MissingPluginException`；而 `menu_service.dart:196-205`、`track_notification_service.dart:96-99` 都有兜底。
- 改法：只包住 `setup()` 一步 try/catch + `AppLogger.warning`，其余订阅照常建立。

### 4.8 🆕² `MenuService` 订整个 `PlayerService`，每 ~200ms 做一次 UI 树祖先遍历（2026-11-07 复核：UI 树查询已缓存化 ✅，订阅面仍未收窄）
- 位置：`MenuService._init()` 里的 `_player.addListener` → `_push()`（`_isTextEditing` / `hasKeyboardFocus` 已改为 Focus 变化时缓存）。
- 后果：播放全程每 200ms（外加睡眠定时每秒一次）遍历祖先链；且 `primaryFocus.context` 若落在已 defunct 的 element 上，断言异常会从 ChangeNotifier 监听链抛出（debug 下变 fatal 日志）。
- 改法：改订 `_player.uiListenable`（已覆盖推送用到的全部字段）+ `_sleepTimer.state`；`_isTextEditing` 结论在 Focus 变化时算一次并缓存。
- 说明：与 5.5「整 service 订阅者可接受」不冲突 —— 5.5 的守卫只把 `position` 去重，本条的问题是**每次推送都做 UI 树查询**。

### 4.9 🆕² ~~`MenuService._push()` 在通道失败时仍记快照~~ ✅（2026-09-29）
- **已修**：`catchError` 里清 `_lastPushed`，下次推送重试；`menu_service_test` 新增「推送失败后同一状态也会重推」用例。
- 位置：`menu_service.dart:194-206`（`_lastPushed = state;` 在 `invokeMethod` 之前，`catchError` 只记日志）。
- 后果：启动早期通道未就绪时那次推送丢失，菜单使能/标题/勾选保持原生默认值，直到状态再变化一次才纠正。
- 改法：`catchError` 内 `_lastPushed = null;`，让下次推送重试。

### 4.10 🆕² `DetailTopBar` 的窗口通道调用无兜底
- 位置：`DetailTopBar` 的窗口通道调用（`invokeMethod` 未 await、无 `catchError`），只靠 `defaultTargetPlatform` 判断平台。
- 后果：通道缺失/异常时是未捕获异步异常（fatal 日志），与 R4/R6 时期定下的「平台通道调用要按平台守卫并兜底」不一致。
- 改法：`.catchError` 记 `AppLogger.warning` 即可。

## 5. 播放引擎 / 播放器 / 持久化

- ~~P4 写盘防抖（队列 debounce + 串行写链 + 生命周期 flush、音量拖动结束落盘）~~
- ~~5.2 封面缓存扩展名不一致~~
- ⛔ ~~5.1 大队列 `setAudioSources` 一次性构建~~ **已失效**：引擎已换 audioplayers（单曲 `AudioEngine`），`setAudioSources`/`_rebuildSequence` 全库 0 命中。替代关注点见 5.7b。
- ~~5.4 `settings.json` 写无串行化与非原子写（改**串行写链** + temp/rename **原子写**；2026-09-17 ✅）~~
- ~~5.8 `settings.json` 解析零容错（损坏则备份为 `.corrupt` 并用默认设置继续启动；2026-09-17 ✅）~~
- ~~5.6 切歌加载无串行/代际（新增 `_loadGeneration`：过期加载在 await 后直接丢弃；2026-09-17 ✅）~~
- ~~5.7 引擎迁移沉淀问题（load 起始清空 `_duration/_position` + `_loadedIndex` 延后到加载成功；切歌先清零持久化位置；`setLoopSingle`/释放模式去重；`load()` 无条件 pause；`isPlaying`/`togglePlay` 改用播放意图 `_shouldPlay`；2026-09-17 ✅）~~

### 5.3 位置每几秒整份重写 `play_queue.json`
- 位置：`PlayerService` 的位置落盘（1s tick → 5s 节流）；`PlayQueue.save()` 每次写全部 `filePaths`（千首歌可百 KB）。
- 改法：`positionMs/durationMs` 拆独立小文件/独立 key。

### 5.5 ○（可选残余）`_positionSub` 每 200ms 唤醒订整个 service 的订阅者
- 位置：`PlayerService._positionSub`。现存整 service 订阅者均有去重守卫（`PlayerBar` / `MenuService` / `MediaControlService` / `App` / `NowPlayingBar`）→ 可接受。

### 5.7b 引擎迁移剩余项（2026-09-17 修复后）
- `player_service.dart:497-505`：shuffle 下 `effectiveQueue` 每次访问 O(n) 重建 + `indexOf` → 缓存并按队列/顺序表失效。
- 文档约束：单曲引擎无预加载 → 结构性曲间空白；应在 `docs/AudioEngine-Migration.md` 写明「不得用位置提前量切歌」，避免后人"修"出截尾。

### 5.9 🆕² ~~加载窗口内按暂停会被静默推翻（高）~~ ✅（2026-09-29）
- **已修**：`_loadCurrent` 起播前复查播放意（`if (autoPlay && _shouldPlay)`）；`player_service_queue_test` 新增「加载窗口内按暂停」用例。
- 位置：`player_service.dart:352`（`_shouldPlay = autoPlay`）→ `:361`（`await _engine.load(...)`）→ `:362`（`if (autoPlay) await _engine.play()`，不复查用户意图）。
- 场景：audioplayers 的 `load()`（`setSourceDeviceFile` + `getDuration`）是真实等待窗口（慢盘/大文件更久）；用户「点歌 → 立刻点暂停」时 `pause()` 只把 `_shouldPlay` 置 false，加载返回后第 362 行仍起播。
- 后果：`isPlaying`（= `_shouldPlay`）为 false 但声音在放 —— 播放页/底栏图标、菜单「播放/暂停」标题、Now Playing 的 rate 全显示「已暂停」，再点一次才恢复一致。
- 改法：`:362` 改 `if (autoPlay && _shouldPlay)`（`_shouldPlay` 已是播放意图的唯一权威）；或让 `pause()` 自增 `_loadGeneration`，使在途加载整体作废。

### 5.10 🆕² `playingNotifier` 与 `isPlaying` 双源
- 位置：`PlayerService.playingNotifier`（初值取引擎、只由引擎事件写）；消费方 `NowPlayingBar`、`LibraryViewModel`。
- 现状：消费方只把它当「重建触发器」不读值，故目前无症状；但引擎事件缺失（release 抛错、状态未上报）时它会与 `_shouldPlay` 分叉，日后若有人读值就会出 UI 不一致。
- 改法：在 `pause()/stop()/stopPlayback()/_finishQueue` 里与 `_shouldPlay` 一并同步，或删除它、统一用 `_shouldPlay + notifyListeners()`。

## 6. 歌词

### 6.1 两遍匹配误判（已修，2026-09-17 ✅）
- ~~片头多行共用同一时间戳（作词/作曲/编曲）时误判切点，整首歌词被归入翻译段；已加「切点前至少两个不同时间戳」守卫，并在 `lyrics_split_test.dart` 补回归用例。~~

### 6.2 外部 `.lrc` 无缓存，切歌/切翻译开关都重读重解析（低）
- 位置：`LyricsViewModel._loadForSong()` + `splitBilingualLrc`（UI isolate 同步跑）；内嵌歌词已有 mtime 缓存，外部没有。
- 改法：加「路径+mtime → 文本/拆分结果」缓存。

### 6.3 `LyricsViewModel` 启动期即读当前歌歌词（低）
- 位置：`LyricsViewModel` 构造期间即 `_onSongChanged()` → 立刻读盘（`resolveLrcPath` 用 `existsSync`）。
- 改法：延迟到播放页首次可见/首次播放。

## 7. 平台 / 发布检查（2026-09-17 复核，同日处理完毕）

- ~~R1 版本与 CHANGELOG~~ ✅：`CHANGELOG.md` 把 13 个重复 `[0.1.0]` 头合并为单一 `[0.1.0]`（08-02）与 `[0.0.1]`（07-27），并按实际版本号重排：`[0.2.3] - 2026-09-17`（引擎迁移 + 审计修复 + 发布清单）、`[0.2.2] - 2026-09-08`、`[0.2.0] - 2026-09-03`。`pubspec.yaml` 已 bump 到 `0.2.3`。
- ~~R2 设置页「清理缓存」占位假功能~~ ✅：改为真实清理——复用 `SongRepository.cleanupOrphanCovers()` 删除未被引用的封面，SnackBar 报数量并刷新缓存大小。
- ~~R3 `audio_metadata_reader` 分支依赖未 pin~~ ✅：`pubspec.yaml` 固定到 commit `4a6f245413d8f0f11f4a8e7613a9ae9ee0681eae`（不再跟随分支）。
- ~~R4 菜单通道仍 `flutter_music/menu`~~ ✅：Dart（`menu_service.dart`）与 Swift（`AppDelegate.swift`）同步改为 `com.jerryc.txvziwm/menu`。
- R5 `macos/Runner/Info.plist:37` `FLTEnableImpeller=false` 全局关 Impeller → **决策：保留现状**（Intel macOS 上 Impeller 闪烁/阴影栅格问题未解）；已记入 `docs/TODO.md` §2，待上游修复后按机型重评。
- ~~R6 `setTopBarHeight` no-op + Dart 侧死调用~~ ✅：Dart `_windowChannel` / `_syncTopBarHeightToNative()` 与 Swift 侧注释一并移除；同通道的 `setTopBarGuard` / `setActionsWidth` 保留（顶栏双击拦截）。
- R7 Windows `WM_GETMINMAXINFO`：**移出本轮发布范围**（需 Windows 环境验证），保留在 `docs/TODO.md` §3 Phase 4。
- R8 Windows/Linux SMTC：**移出本轮发布范围**（本轮为 macOS 发布），保留在 `docs/TODO.md` §3 Phase 5。
- ~~R9 macOS 权限方案与 README~~ ✅：采用方案 C——README 新增「macOS permissions」小节（媒体与 Apple Music 手动添加）；`audio_metadata_reader` 补 fork 仓库链接与固定 commit。
- R10 `assets/fonts/BoutiqueBitmap9x9_Circle_Dot.ttf`（5.8MB，无声明无引用）：文件暂留，已登记 `docs/TODO.md` §2 待删。该文件未在 `pubspec.yaml` 声明，不会进 app 包，不阻塞发布。
- ~~R11 `docs/TODO.md` 过时描述~~ ✅：菜单栏标为已完成、Phase 2/3 关闭、`Runner.rc` 更正为已是 `0x4D`。
- ~~R12 文档与测试样本~~ ✅：`docs/UI-Rules.md` 部署目标改 12.0 并删除已失效的 `setTopBarHeight` 描述；README 补「改 `macos/` 需 `rm -rf build/macos` 重建，勿用 `flutter clean`」；`test/log_page_test.dart` 样本去 `MetadataGod`。
- 验证：`flutter analyze lib` 无问题；`flutter test` 225 通过。

## 8. 睡眠定时 / 通知 / HUD 反馈（2026-09-22 审查新增）

### 8.1 🆕² ~~睡眠定时到点的 5 秒淡出期间无法取消，且「按播放」会被再次暂停（高）~~ ✅（2026-09-29）
- **已修**：新增 `SleepTimerState.fading`，淡出期间状态保持激活（取消入口不再消失）；`cancel()` 去掉早退并无条件 `cancelFadeOut()`；`PlayerService.play()` 主动中止淡出（不再被尾部 `pause` 摸掉）；状态在被用户起播接管时由 `_onPlayerChanged` 收回。
- 位置：`sleep_timer_service.dart:203-209`（`_notify()` 先 `state.value = null` 再 `await _player.fadeOutAndPause(...)` — UI 立即认为「未激活」，实际还要响 5 秒）、`:135-141`（`cancel()` 首行 `if (!isActive && _timer == null) return;`，即使被调到也不会 `cancelFadeOut()`）。
- 连带：`sleep_timer_button.dart:129-137`（「取消定时」项仅 `active` 时构建）、`AppDelegate.swift:230-232`（原生「取消」项读 `sleepTimerMode != "off"`）→ 淡出期间两个入口都消失/置灰。
- 更糟：淡出期间用户点「播放」→ `togglePlay()` 因 `_shouldPlay == true` 走 `pause()`；用户再点一次播放后，`player_service.dart:723` 尾部的 `if (_shouldPlay) await pause()` 又把刚恢复的播放停掉（表现为「按播放没反应」）。
- 改法：给状态加 `fading` 标志（淡出期间仍算 active，UI/原生菜单据此保留取消入口）；把 `cancelFadeOut()` 提到 `cancel()` 的早退判断之前；`fadeOutAndPause` 尾部的 `if (_shouldPlay) await pause()` 改为只在「本次淡出未被取消/未被重新起播」时执行。

### 8.2 🆕² ~~倒计时按 tick 递减而非按 deadline~~ ✅（2026-09-29）
- **已修**：`startForDuration` 记 `_deadline`，每个 tick 用 `DateTime.now()` 差值算剩余（测试用 `tick: 20ms` 验证仍与真实时间对齐）。
- 位置：`sleep_timer_service.dart:174-182`（`next = current!.remaining! - tickInterval`）。
- 后果：定时器被节流或系统睡眠期间剩余时间不随真实时间推进（醒来仍剩原分钟数），且每次 tick 的调度误差持续累积 —— 与「定 30 分钟就是 30 分钟」的预期不符。
- 改法：`startForDuration` 记 `deadline = DateTime.now().add(duration)`，每次 tick 用 `DateTime.now()` 差值算剩余。

### 8.3 🆕² ~~`notif_attachments/` 只增不减，且同一首歌反复切会重复拷贝~~ ✅（2026-09-29）
- **已修**：拷贝前比对大小/mtime（相同则直接复用），并按 **7 天 TTL + 每小时一次节流**清理旧副本。
- 位置：`track_notification_service.dart:158-176`（`_copyCoverForAttachment`）：每首歌把封面复制到 `Documents/notif_attachments/cover_<songId><ext>`，先 `delete` 再 `copy`。
- 后果：① 长期使用按曲库规模持续占用沙箱磁盘，**没有任何清理策略**（`cleanupOrphanCovers` 只管 `covers/`）；② 来回切换同一首歌会反复 delete+copy 整份图片。
- 改法：拷贝前比对文件大小/mtime，一致则跳过；在孤儿封面清理（或启动 quickSync）时同步清掉不在库中的 `cover_*` 副本。

### 8.4 🆕² ~~淡出刚开始就提示「已暂停」，与听感不符~~ ✅（2026-09-29）
- **已修**：提示改到淡出真正结束之后发，且只在确实停下时发（被取消/被起播接管时不发）。
- 位置：`sleep_timer_service.dart:206-209`（`_notify('睡眠定时结束，已暂停')` 在 `fadeOutAndPause` 之前）。
- 改法：提示移到淡出结束之后发，或文案改为「睡眠定时结束，正在淡出…」。

### 8.5 🆕² ~~`PlaybackFeedbackService.stop()` 的注释/文案与实际行为不符~~ ✅（2026-09-29）
- **已修**：注释改为「保留队列与当前曲目」，HUD 文案改「已停止 · 保留队列」；`_StubPlayer.stopPlayback` 也改成与真实实现一致（原来在测试里模拟的是「清空队列」）。
- 位置：`playback_feedback_service.dart:112-127`（注释称「停止会清空队列，底栏随即变成未在播放」），实际调用 `PlayerService.stopPlayback()`（`player_service.dart:650-658`：保留队列与当前曲目，只归零位置）。
- 后果：按 ⌘. 后底栏仍显示当前曲目，与注释/UI 约定不一致，后续维护容易被误判为 bug 或误改。
- 改法：注释与 HUD 文案改为「已停止（保留队列，再播从头开始）」，或让 `stop()` 真正调用会清队列的 `PlayerService.stop()`。

### 8.6 🆕² ~~通知点击唤回窗口的异常被静默吞掉~~ ✅（2026-09-29）
- **已修**：补 `AppLogger.warning('Notify', 'Failed to restore main window', e)`。
- 位置：`track_notification_service.dart:262-270`（`catch (_) {}`）。
- 后果：违反 `docs/ErrorHandling.md` §5「禁止静默」；用户点了横幅但窗口没出现时，日志里查不到痕迹。
- 改法：`catch (e) => AppLogger.warning('Notify', 'Failed to restore main window', e)`。

### 8.7 🆕² ~~通知「仅后台弹」与设置项文案的语义落差（低）~~ ✅（设置项副标题已写明「只应用在后台/关窗时弹出，前台不打扰」）
- 位置：`track_notification_service.dart:118-131`（`presentBanner/presentList/presentAlert = false`，刻意设计）+ `settings_page.dart:331-339`（设置项「切歌时显示系统通知」）。
- 说明：前台不弹是有意为之（窗口可见时用户本就看到底栏），但设置项名没写「仅在后台」，容易被当成「开关失效」。
- 改法：设置项副标题补「仅在窗口不在前台时显示」，或在 `docs/UI-Rules.md` 写明该策略。

## 9. macOS 原生层（2026-09-22 审查新增）

### 9.1 🆕² 原生在主线程同步解码整张封面（2026-11-07 复核：仍未修，见 §12.2）
- 位置：`MediaControlsPlugin` 的全量 Now Playing 推送（`NSImage(contentsOfFile:)` +
  `MPMediaItemArtwork(boundsSize: image.size)`），位于方法通道回调（主线程）。
- 现状：`_pushCurrent` 在切歌、播放态翻转、时长刚解析出来时都会全量推送（每秒的 `updateElapsed` 已优化掉，见 4.1 ✅），这里成了剩下的热点。
- 后果：Hi-Res 专辑 2000~3000px 封面每次解码数十 ms，表现为切歌/暂停瞬间掉帧、窗口与菜单响应迟滞；`boundsSize` 传的是原图点尺寸，任何请求尺寸都会返回全分辨率图。
- 改法：`boundsSize` 固定为合理显示尺寸（如 600×600）；解码挪到串行后台队列 + 按路径 `NSCache`，`MPMediaItemArtwork` 闭包只返回缓存图。

- ~~9.2 🆕² 原生「空格」键等价吞掉除文本框外的一切空格~~ ✅（2026-09-23）
  - 位置：`macos/Runner/AppDelegate.swift`（`keyEquivalent: " "` + `keyEquivalentModifierMask = []`，见 `docs/Pitfalls.md` B4），守卫原是 `menuState.hasTrack && !menuState.isTextEditing`。
  - ⚠️ **原「改法」那半句是错的**：`primaryFocus` 在启动后就是路由自身的 `FocusScope`（`ModalRoute` autofocus）——「非空即占用空格」会让空格**永远**不再播放 / 暂停。
  - 实际修法：新增 `hasKeyboardFocus`（`primaryFocus` 非空且**非** `FocusScopeNode`，`lib/core/utils/keyboard_focus.dart`），`MenuService` 随菜单状态一起推；`applyMenuItemState` 的 `playPause` 分支据此禁用裸空格键等价 ⇒ 有控件聚焦时空格归 Flutter（激活聚焦控件，与 Enter 一致）。
  - 顺带（同日）：`_isTextEditing` 也改为只在 Focus 变化时算一次并缓存，收掉 4.8 的「每次推送都做 UI 树查询」。
  - **剩余（未做）**：弹层 / 对话框在最上层且无控件聚焦时，空格仍是播放 / 暂停 —— 需一个「最上层路由是 `PopupRoute`」的信号，见 §10.3。

- ~~9.3 🆕² `⌘.` 监控器不区分额外修饰键，且 fallback 绕过菜单项使能~~ ✅（2026-09-23）：`installKeyShortcutMonitor` 改为剔除 `.capsLock/.function/.numericPad` 后要求**恰好** `.command`（⌘⇧. / ⌘⌥. 不再误入）；fallback 前查 `menuState.hasTrack`（无曲目不再弹 HUD「已停止」，与菜单项使能一致）。
- **待实机复验**：`NSMenu.performKeyEquivalent` 对 disabled 项的确切匹配行为（本机未验证；同类经验见 `docs/Pitfalls.md` B2/B6）。

### 9.4 🆕² 单曲循环开启时，原生「播放模式」子菜单三项全不勾选
> 状态：**按用户决定暂缓**（2026-09-23 明确先不做；修法见下，改动本身很小，只差通道多推一个 `baseRepeatMode`）。
- 位置：`AppDelegate.applyMenuItemState` 的「播放模式」三项（只比 `off` / `all` / `shuffled`）← `MenuService._push()` 推的是 `_player.repeatMode.name`，单曲循环下为 `"one"`（`PlayerService.baseRepeatMode` 才是底层模式）。
- 后果：菜单栏勾选与实际状态不同步；用户也看不出退出单曲循环后会回到哪种模式（队列底部状态行用的是 `baseRepeatMode` 语义，两处表达不一致）。
- 改法：推 `baseRepeatMode.name` 供「播放模式」三项使用，`repeatMode` 只给「单曲循环」项。

- ~~9.5 `as!` 强转改 `guard let`~~ ✅（2026-09-23）：`applicationDidFinishLaunching` 改 `guard let ... as? FlutterViewController else { NSLog(...); return }`——取不到就不注册原生通道，也不再崩在启动阶段绕过启动错误页。

## 10. 🆕³ 键盘操作与焦点（2026-09-23 新增）

### 10.1 🆕³ Tab 进入键盘导航后没有退出口（高，2026-09-23 ✅）

- 现象：按 Tab 后焦点环出现就再也退不掉（鼠标点击无效、Esc 无效），再按空格会激活那个（有时已看不见的）聚焦按钮。
- 根因（3.47 实测，三条缺一不可）：
  1. Esc 的框架默认映射是 `DismissIntent`，而普通页面路由 `barrierDismissible == false` ⇒ `_DismissModalAction` 被禁用 ⇒ 整条链 no-op；
  2. Flutter 的 `InkWell` 点击**既不请求焦点也不 unfocus** ⇒ 点别处不会摘掉旧焦点环；
  3. `_HighlightModeManager.handlePointerEvent` 只处理 touch/stylus，**mouse/trackpad 落空** ⇒ 鼠标连「切回 touch 模式以隐藏焦点环」都不会发生（macOS 默认模式本来就是 traditional）。
- 修法：`FocusManager.instance.addLateKeyEventHandler`（Esc → 取消焦点）+ 根 Scaffold body 外包 `GestureDetector(behavior: translucent, onTap: 取消焦点)`。
- 落点：`lib/core/utils/keyboard_focus.dart`（`hasKeyboardFocus` / `clearKeyboardFocus` / `handleKeyboardFocusKeyEvent`）、`app.dart`（注册 + 根级手势）。
- 护栏：`test/keyboard_focus_test.dart`（4 例）；`docs/Pitfalls.md` C5/C6、`docs/UI-Rules.md` §10。

### 10.2 🆕³ 有控件聚焦时空格被原生吞掉（高，2026-09-23 ✅）

- 与 §9.2 是同一问题（同一个修法），已完成；本条只作为「键盘归属」的总入口保留。

### 10.3 🆕³ 弹层在最上层且无控件聚焦时，空格仍是播放 / 暂停（低，未做）

- 现状：`showDialog` / 底部弹层打开时焦点在弹层自身的 `FocusScope` 上 ⇒ `hasKeyboardFocus` 为 false ⇒ 原生裸空格仍生效。
- 改法：推一个「最上层路由是 `PopupRoute`」的信号（`lib/core/navigation/route_observer.dart` 旁加个小 observer，或扩展现有 `routeObserver`），原生据此一并让出空格。
- 取舍：现状不算错（空格=播放/暂停是全局约定），故暂不做。

---

## 11. 优先级建议（2026-09-22 重排）

> 改动量估计：**S** = 单文件、半天内可完成；**M** = 需改多文件或补测试；**L** = 架构级、需专门时间窗。
> 编号对应本文各节；`~~删除线~~` = 已完成。

### 11.1 已清空的历史批次

- ~~数据 / 状态风险：2.9、2.10、3.10、5.4、5.8~~ —— 2026-09-17 ✅
- ~~发布清单：R1、R2、R3、R4、R6、R9、R11、R12~~ —— 2026-09-17 ✅
- ~~键盘 / 原生菜单：9.2、9.3、9.5、10.1~~ —— 2026-09-23 ✅（另附 4.8 的「每次推送都查 UI 树」缓存化）
- ~~审查第一批：5.9、8.1、8.2、8.3、8.4、8.5、8.6、4.7、4.9~~ —— 2026-09-29 ✅（8.7 的设置项文案同日补）

### 11.2 第 1 批 — 用户可见行为 ✅ 2026-09-29 完成

见 11.1。唯一未动的仍是 **9.4**（单曲循环时原生「播放模式」勾选），按你的决定继续暂缓 —— 改动很小，只差通道多推一个 `baseRepeatMode`。

### 11.3 第 2 批 — 有可测收益的性能项

1. **9.1** 原生主线程解码整张封面（M，目前唯一可能明显掉帧的原生热点）
2. **4.8（剩余）** 菜单订阅面改订 `uiListenable`（S；每次推送的 UI 树查询已缓存化 ✅ 2026-09-23）

### 11.4 第 3 批 — 一致性收尾（低风险顺手）

- **4.10** `DetailTopBar` 通道兜底、**5.10** 播放态双源（把其他 notifier 收口到 `_shouldPlay`）
- **2.6** 删除死 watch 流、**2.11 / 2.12** 初始化重试释放与扫描反馈、**3.11** `restoredFiles` 的 isolate 归并

### 11.5 第 4 批 — 第二轮架构（需专门时间窗）

- **2.1** 启动路径 `Future.wait` 并行、**2.2** 先出列表再后台 quickSync
- **2.3** DB 移后台 isolate（需真实库验证，风险中）
- **2.8** 补 `(is_available, date_added)` 等复合索引
- **R7** Windows 窗口最小尺寸、**R8** Windows SMTC（均需 Windows 环境）

### 11.6 发布事项（与性能优化无关）

- **R5** `FLTEnableImpeller=false` 保留现状（决策见 §7 与 `docs/TODO.md` §2）
- **R7 / R8** 移出本轮 macOS 发布范围
- **R10** `assets/fonts/BoutiqueBitmap9x9_Circle_Dot.ttf`（5.8MB，无引用）待删，已登记 `docs/TODO.md` §2

## 12. 🆕⁵ 2026-11-07 复核：0.4.x 新功能（i18n / 播放页展开 / 歌词 / 变形菜单）

> 审查范围：`2cd6212..f75361e`（0.2.6 → 0.4.1，238 个文件）。
> 结论：**没有发现新的数据安全类问题**；i18n、平台目录清理、返回键 / 窗口几何的生命周期
> 都已核查通过（见 §12.10）。下面只记值得做的项。

### 12.1 歌词布局仍是最大的单点开销（§1.7.1 未做）
- 现状（2026-10-29 实测）：重开播放页挂载歌词栏 ui 62–65ms + raster 40–44ms；
  稳态跟唱每帧 raster 18–30ms。
- 建议顺序：**先做 B**（fork 里只量可见行 + 按
  `(documentRevision, resolvedStyle, viewSize)` 缓存），一次覆盖重开 / 切歌 / 切翻译 / resize；
  A（State 常驻）只解决重开，还要处理隐藏时停 ticker。细节见 §1.7.1。

### 12.2 原生主线程解码整张封面（§9.1 仍未修）
- 位置：`MediaControlsPlugin` 的全量推送（`NSImage(contentsOfFile:)` +
  `boundsSize: image.size`，位于方法通道回调 = 主线程）。
- 改法：`boundsSize` 固定 600×600；解码挪到串行后台队列 + 按路径 `NSCache`；
  `MPMediaItemArtwork` 闭包只返回缓存图。

### 12.3 `_RevealGate` 缺超时兜底（中，用户可见）
- 位置：`_RevealGate`（`player_page.dart`）+ `_panelCanShow`。
- 现状：右栏要等 `revealed && !loading`，只靠 `lyrics.loadStateNotifier` 推进。
- 风险：歌词加载停在 `loading` 不收敛时，右半屏会**永久空白**。
- 改法：加 500ms 兜底（到点无条件放行）；或在 `LyricsViewModel` 的异常路径保证置终态。

### 12.4 UI 语言与原生菜单语言不联动（中，产品一致性）
- 位置：`app.dart` 的 `_onLocaleChanged` 只刷新歌词与通知动作；
  `AppDelegate.swift` 的菜单 / 对话框文案全部走 `NSLocalizedString`（跟随**系统**语言）。
- 现象：界面设成 English、系统是中文时，界面英文而菜单栏 / `NSAlert` 仍是中文。
- 取舍：接受的话写进 `docs/I18n.md`（「原生菜单跟随系统语言，不跟随界面语言」）；
  要一致则新增通道把 `locale` 推给原生并重建菜单标题（工作量 M）。

### 12.5 `BottomBarReveal` 的带高兜底偏大（低）
- 位置：`_BottomBarRevealState._bandHeight`（`bottom_bar_reveal.dart`，
  `?? fallbackBandHeight`，兜底 140）。
- 实际带高：宽版 64 / 窄版 44（由控制按钮尺寸决定）。
- 影响：量不到时（首帧 `bandKey` 尚未布局）带子阶段收尾高度对不上，观感跳一下。
- 改法：兜底值按窗口宽度取 64/44，或在下一次 postFrame 重试测量。

### 12.6 `MenuMorphRoute._curved` 未 dispose（低）
- 位置：`MenuMorphRoute.createAnimation()`（`menu_morph_route.dart`）。
- 说明：`CurvedAnimation` 会给 parent 挂监听；Route 销毁时没调用它的 `dispose()`。
- 改法：override `dispose()` → `_curved?.dispose()`。

### 12.7 歌词设置预览的 Ticker 常驻（低）
- 位置：`_LyricsPreviewState` 的 `createTicker(_onTick)..start()`（`lyrics_preview.dart`）。
- 现状：`TickerMode` 只感知路由 / 标签页，感知不到「预览滚出视口」；设置页开着就一直每帧跑。
- 改法：滚动可见性判断，或 `Visibility` + `TickerMode` 包一层。

### 12.8 l10n 缺 key 对齐的测试护栏（低）
- 现状：`app_en.arb` / `app_zh.arb` 各 293 key，人工核对完全一致；`test/l10n_test.dart`
  只测 locale 映射，**没有**断言两边 key 集合一致。
- 改法：加一个测试比较两 ARB 的 key 集合（漏翻会直接失败）。

### 12.9 右键菜单的锚点计算重复（低，代码质量）
- 位置：6 处 `_showXxxMenu`（`album_page.dart` / `artist_page.dart` / `queue_view.dart` /
  `playlist_page.dart` ×2 / `lyrics_view.dart`），各自算 `anchorRect` + `panelSize`。
- 建议：抽公共 `showRowMenu(anchorContext, entries)`；`docs/Pitfalls.md` 已记过
  「写死宽度导致溢出」的先例。

### 12.10 已核查通过（不用重复排查）
- **i18n 迁移彻底**：`lib/` 内 UI 字符串中文残留 **0 处**（注释除外）；语言切换会重新解析歌词 +
  重注册通知动作（`app.dart:171-178`、`track_notification_service.dart:99-122`）。
- **平台目录移除干净**：无 `Platform.isAndroid/isIOS/kIsWeb` 或 android/ios 路径残留；
  `README.md:44/55-56` 已声明平台范围。
- **生命周期 / 资源**：返回键 late handler 在 `app.dart:184-188` 移除；窗口几何 0.4s 防抖 +
  三处事件兜底 + 多屏 `fitted` 钳制（`MainFlutterWindow.swift:118-185`）。
- **测量探针已清理**：`addTimingsCallback` / `AUTO_OPEN_PLAYER_SECONDS` 在 `lib/` 0 命中。

### 12.11 建议顺序
1. §12.2（原生封面解码）与 §12.3（reveal 兜底）：半天内、可验证。
2. §12.8（l10n 护栏）：十分钟，防回归。
3. §12.1（歌词布局，B 方案）：需要动 fork，单独排期。

## 13. 🆕⁵ 2026-11-07 遗留项盘点

> 逐项读实现核对（不是只读文档）。结论：**没有发现新的数据安全类风险**，
> 但部分条目的措辞与定位需要修正。

### 13.1 仍然成立（需做）

| 分类 | 编号 | 现状依据（符号定位） |
|---|---|---|
| UI | 1.5 | `_PlaybackFill.build()` 仍订整个 `PlayerService` |
| UI | 1.6 | ①每秒重建 ②菜单打开期间不刷新（③已修） |
| 启动 | 2.1 | `_doInitialize()` 串行 await，版本号在最前 |
| 启动 | 2.3 | `AppDatabase.create()` 用主 isolate 的 `NativeDatabase` |
| 启动 | 2.4 | `getExistingFileStats()` 仍全列物化 |
| 启动 | 2.5 | `backfillSortKeys()` 无 COUNT 短路（但只查 NULL 行，收益小） |
| 启动 | 2.6 | 6 个 `watch()` 死代码 |
| 启动 | 2.7 | `getAllFilePaths()` 仍全列物化 |
| 启动 | 2.8 | 7 个索引里没有 date_added / play_count 复合索引 |
| 启动 | 2.11 | `resetInitialization()` 不 dispose 旧实例 |
| 启动 | 2.12 | 扫描中强制刷新仍无 UI 反馈 |
| 扫描 | 3.5 / 3.6 / 3.7 / 3.8 / 3.11 | 全部仍成立（详见各节） |
| 服务 | 4.2 | 每条日志 `flush()` |
| 服务 | 4.3 | 媒体键仍 fire-and-forget |
| 服务 | 4.8 | 仍订整个 `PlayerService` |
| 服务 | 4.10 | `DetailTopBar` 通道无兜底 |
| 播放 | 5.3 | 位置与队列写在同一份文件 |
| 播放 | 5.5 | 200ms 唤醒整 service 订户（已评估：可接受） |
| 播放 | 5.7b | `effectiveQueue` 每次 O(n) 重建 |
| 播放 | 5.10 | `playingNotifier` 与 `_shouldPlay` 双源 |
| 歌词 | 6.2 / 6.3 | 外部 `.lrc` 无缓存；构造期即读盘 |
| 原生 | 9.1 / 9.4 | 封面主线程解码；播放模式勾选（按决定暂缓） |
| 键盘 | 10.3 | 缺「最上层是 `PopupRoute`」的信号 |
| 发布 | R5 / R7 / R8 / R10 | 决策项未变；R10 字体文件仍在 `assets/fonts/` |

### 13.2 已失效或需改措辞

- **2.5**：查询已只取 `sort_key IS NULL` 的行，加 COUNT 短路的收益比原估计小 → 建议降级或并入 §3。
- **3.7**：`isNotIn` 已不存在；现状是「全表取 song id 到 Dart + `isIn` 删除」——结论（改 `NOT EXISTS`）不变，方法描述已更新。
- **1.6 ③**、**4.8 的 UI 树查询**、**9.2 / 9.3 / 9.5 / 10.1**、**§8 全部**：已完成（见 §11.1）。

### 13.3 文档维护规则（本次已落实）

- **不再写行号**，改用「文件 + 符号（类 / 方法名）」定位；本次已把 §1.5、§2.x、§3.x、
  §4.2/4.3/4.8/4.10、§5.3/5.5/5.10、§6.2/6.3、§9.4 改成符号定位。
- **路径以实际文件为准**：`library_view_model.dart` 在 `lib/features/library/`（不在 `lib/core/viewmodels/`）。
- 每次复核只更新「仍然成立 / 已失效」两栏，不重写已有分析。

### 13.4 建议的下一批（按链路打包）

1. **启动 + 扫描链路**：2.1 + 2.3 + 3.5 + 3.6 + 3.11 + 2.4/2.7 —— 同一调用链，一次改完一起测
   （预计启动时少 2 次全表扫）。
2. **播放高频路径**：5.3（位置独立落盘）+ 1.5（进度 Notifier）+ 4.8（订阅面收窄）。
3. **原生**：9.1（封面解码）单独一个 Release 构建验证。

