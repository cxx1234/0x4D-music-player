# 性能与待优化项清单

> 删除线 = 已完成；其余为待办。⛔=已失效/不再适用；🆕=2026-09-17 审计新增。
> 🆕²=2026-09-22 审查新增（针对 0.2.4–0.2.6 的睡眠定时 / 通知 / HUD / 原生菜单）。
> 🆕³=2026-09-23 新增（键盘焦点 / 空格归属，见 §10）。
> 最后更新：2026-09-23（§9.2 已修且修法已修正、§9.3/§9.5 已完成、§9.4 按用户决定暂缓；新增 §10、优先级建议顺延为 §11；其余行号按 2026-09-17 代码）

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
- 位置：`now_playing_bar.dart:196-216`（`_PlaybackFill` 订整个 `PlayerService`）。
- 现状：绘制已用 `RepaintBoundary` 隔离（1.4 ✅），但每次 position tick 仍走一遍 build（`FractionallySizedBox` + `ColoredBox`），只是重建范围小。
- 改法：暴露一个只带 progress 的 `ValueNotifier<double>`（或让填充层订它），让 build 只在百分比变化时发生。

### 1.6 🆕² 睡眠定时按钮的刷新粒度与菜单勾选
- 位置：`sleep_timer_button.dart:50-92`（`ValueListenableBuilder` 订 `state`，倒计时**每秒重建整颗按钮**）+ `:105-137`（`_buildItems`）。
- 问题：① 每秒重建含 `PopupMenuButton` 与文本格式化的整棵子树，开销可忽略但可免；② **菜单打开期间剩余时间不刷新**（`PopupMenuButton` 一次性构建 items）；③ 预设项用普通 `PopupMenuItem`（`:114-118`）无勾选态，而原生菜单会勾选 —— 同一功能两个入口反馈不一致。
- 改法：预设项改 `CheckedPopupMenuItem`（`checked: state?.mode == SleepTimerMode.duration && state?.requested?.inMinutes == preset.inMinutes`）；若在意菜单里的实时倒计时，可改用 `showMenu` + 自持 `ValueListenableBuilder` 列表。

---

## 2. 启动 / 数据层类

- ~~P3 DB schema v6（7 索引）+ WAL + 队列恢复批量查询~~
- ~~2.9 扫描根读取失败时整根被误标不可用（改为只用成功读取的根 `okRoots` 做 diff；2026-09-17 ✅）~~
- ~~2.10 文件夹路径 `LIKE '$root/%'` 未转义（改「SQL 粗筛 + Dart 精确判定」，新增 `utils/path_under_root.dart`；`deleteFolderSongs` 改分块 `isIn` 删除；2026-09-17 ✅）~~

### 2.1 启动路径串行阻塞
- 位置：`service_locator.dart:199-250` `_doInitialize()`（新增 `:203` 版本号读取在关键路径最前）。
- 改法：`Future.wait` 并行独立步骤（settings/DB 开库、backfill、restoreQueue、sandbox）；版本号读取移出关键路径。

### 2.2 每次启动全盘遍历阻塞首屏
- 位置：`library_view_model.dart:143-158`（`_quickSync` 在 `_loadSongs` 之前）。
- 改法：先加载歌曲列表再后台 quickSync。

### 2.3 数据库跑主 isolate
- 位置：`database.dart:90-107` `create()`。
- 前置：WAL 已开。风险：中（需全量测试 + 真实库验证）。
- 改法：`createInBackground`/`readPool`。

### 2.4 `getExistingFileStats` 拉全行
- 位置：`database.dart:228-238`。
- 改法：投影 `file_path/last_modified_ms/file_size` 三列。

### 2.5 `backfillSortKeys` 每次启动 3 次无索引全表扫
- 位置：`song_repository.dart:129-147` + `database.dart:677/685/693`（已无全表 UPDATE，但仍未短路）。
- 改法：先 `COUNT(*) WHERE sort_key IS NULL` 短路。

### 2.6 watch 流全是死代码
- 位置：`database.dart:117/383/430/444/475/495` + `song_repository.dart:36/55/62/69/76/87`（零调用）。
- 改法：删除，或改用 drift 流式更新替代手动 reload。

### 2.7 `getAllFilePaths` 拉全行（`getFolderFilePaths` 已修）
- 位置：`database.dart:219-227`（`getAllFilePaths` 仍 `select(songs)` 物化 26 列）；调用点 `library_view_model.dart:340-342`。
- 已修：`getFolderFilePaths` 改为 `selectOnly` 投影 + Dart 精确过滤（见 2.10，2026-09-17 ✅）。
- 改法（剩余）：`getAllFilePaths` 改 `selectOnly(songs.filePath)`；多根合并为一次查询。

### 2.8 dateAdded / playCount / year 排序无复合索引
- 位置：`database.dart:365-371` + `_songOrdering :709-721`（schema 仍 v6、7 索引）。
- 改法：按需补 `(is_available,date_added)` / `(is_available,play_count)`。

### 2.11 🆕 `resetInitialization()` 重试不释放旧实例（中）
- 位置：`service_locator.dart:189-197` 重置 + `:214/227/234` 重建（PlayerService/MediaControlService/LyricsViewModel）。
- 后果：幽灵 AudioEngine + 重复歌词订阅。
- 改法：reset 前 dispose 已建服务，或仅在未创建时允许 reset。

### 2.12 🆕 设置页「强制刷新」在扫描中被静默忽略（中）
- 位置：`library_view_model.dart:255-260`（单飞守卫只 `AppLogger.warning`，UI 无反馈）+ `settings_page.dart:176-180` 跳转音乐库。
- 改法：给 SnackBar 提示或排队执行。

## 3. 扫描 / 元数据类

- ~~3.1 元数据解析并发 + Isolate（受限并发 worker 池 + 100ms 进度节流）~~
- ~~3.2 变化检测移后台 isolate（`detectChangedFiles` + `Isolate.run`；⚠️ 闭包勿捕获 UI 回调，防 unsendable）~~
- ~~3.3 扫描事务查询去重（artist/album 批量缓存 + dateAdded 批量）~~
- ~~3.4 文件夹并行遍历（`Future.wait`）~~
- ~~3.9 扫描单飞守卫（`_scanInProgress` 覆盖 startScan/forceScan/rescan/quickSync——`library_view_model.dart:44/257/296`；2026-09-08 ✅）~~
- ~~3.10 force 清幽灵误删仍在文件（磁盘路径 `p.normalize` 归一化 + `File.existsSync()` 二次确认，统一复用 `isUnderRootPath`；2026-09-17 ✅）~~

### 3.5 待办（行号按 2026-09-17）
- 3.5 扫描无条件拉 `existingStamps`（全库映射；force 与非更新分支都白查）— `library_scanner_service.dart:195`（force `:213-214`、非更新 `:211-212`）。移进变化检测分支并按根限定。
- 3.6 每次 quickSync 都跑 `cleanupOrphans` + 孤儿封面清理（无 mode 判断）— `library_scanner_service.dart:295-296`，每次启动 = 2 次全表扫 + `covers/` 全列（`album_art_cache_service.dart:159-176`）。仅确有增删改/恢复才清；quick 跳过。
- 3.7 `cleanupOrphans` 3 段全表扫 + `isNotIn` 删除 — `database.dart:313-355`。改 `DELETE … WHERE NOT EXISTS`。
- 3.8 `restoreFiles` 逐文件 UPDATE — `song_repository.dart:564-569` + `database.dart:272-278`。仿 `markMissingFiles` 用 `isIn` 批量。

### 3.11 🆕 `restoredFiles` 在主 isolate 逐路径 `existsSync`
- 位置：`library_scanner_service.dart:199-201`，抵消 3.2 把 `statSync` 移入 isolate 的收益。
- 改法：并入 `_detectChangedInIsolate` 或复用目录收集结果。

---

## 4. 后台 / 服务类

- ~~4.1 每秒重读封面 + 整包 push（拆为「全量元数据推送」与新增的 `updateElapsed` 轻量进度通道；Swift 侧只改 elapsed/rate，不再每秒 `NSImage` 重解码；2026-09-17 ✅）~~
- ~~4.4 媒体键 EventChannel `onError` 静默（改为 `AppLogger.warning`；2026-09-17 ✅）~~
- ~~4.5 folder watcher 无防抖 + 扫描期并发触发（已改 500ms 去抖批量 + `suspend()` 扫描期缓冲 + `resumeAfterScan`；`folder_watcher_service.dart:56/127/181`，2026-09-08 ✅）~~
- ~~4.6 watcher 残留问题（`suspend()` 改为 async 并等待在途 flush；跳过项按「事件时间 vs 扫描开始」过滤（force 扫描不再吞掉扫描期间的编辑）；扫描期间已落库的变更在 resume 时补发汇总通知；remove 落库前校验文件确实已不在；2026-09-17 ✅）~~

### 4.2 日志每行 flush
- 位置：`lib/core/utils/logger.dart:229-232`。
- 改法：批量缓冲 + 周期 flush（保持崩溃前落盘语义）。

### 4.3 媒体键操作 fire-and-forget 未串行
- 位置：`media_control_service.dart:49-64`。⚠️ 原依据「与扫描 `_rebuildSequence` 并发」已失效（该方法随引擎迁移删除）；现并发载体为 `PlayerService._loadCurrent`——已加代际守卫（5.6 ✅），剩余风险为连击时的重复下发。
- 改法：给引擎操作加操作串行/统一入口。

### 4.7 🆕² 媒体控制 `setup()` 失败会把「媒体键不可用」升级成整屏启动失败页
- 位置：`media_control_service.dart:48`（`await _controls.setup()` 无 try/catch）→ 冒泡到 `app.dart:47-58` 的 `ServiceLocator.initialize()` catch → `StartupErrorPage`（fatal）。
- 背景：sandbox / menu / media_controls 三个通道都在同一次原生 `applicationDidFinishLaunching` 里注册，Dart 侧初始化先跑就会 `MissingPluginException`；而 `menu_service.dart:196-205`、`track_notification_service.dart:96-99` 都有兜底。
- 改法：只包住 `setup()` 一步 try/catch + `AppLogger.warning`，其余订阅照常建立。

### 4.8 🆕² `MenuService` 订整个 `PlayerService`，每 ~200ms 做一次 UI 树祖先遍历
- 位置：`menu_service.dart:81`（`_player.addListener`）→ `:167-210` `_push()` → `:163-166` `_isTextEditing`（`findAncestorWidgetOfExactType`）。
- 后果：播放全程每 200ms（外加睡眠定时每秒一次）遍历祖先链；且 `primaryFocus.context` 若落在已 defunct 的 element 上，断言异常会从 ChangeNotifier 监听链抛出（debug 下变 fatal 日志）。
- 改法：改订 `_player.uiListenable`（已覆盖推送用到的全部字段）+ `_sleepTimer.state`；`_isTextEditing` 结论在 Focus 变化时算一次并缓存。
- 说明：与 5.5「整 service 订阅者可接受」不冲突 —— 5.5 的守卫只把 `position` 去重，本条的问题是**每次推送都做 UI 树查询**。

### 4.9 🆕² `MenuService._push()` 在通道失败时仍记快照
- 位置：`menu_service.dart:194-206`（`_lastPushed = state;` 在 `invokeMethod` 之前，`catchError` 只记日志）。
- 后果：启动早期通道未就绪时那次推送丢失，菜单使能/标题/勾选保持原生默认值，直到状态再变化一次才纠正。
- 改法：`catchError` 内 `_lastPushed = null;`，让下次推送重试。

### 4.10 🆕² `DetailTopBar` 的窗口通道调用无兜底
- 位置：`detail_top_bar.dart:149-159`（`invokeMethod` 未 await、无 `catchError`），只靠 `defaultTargetPlatform` 判断平台。
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
- 位置：`player_service.dart:75-78`（1s tick）→ `:425-430`（5s 节流）→ `:911-917`；`play_queue.dart:291-307`（每次写全部 `filePaths`，千首歌可百 KB）。
- 改法：`positionMs/durationMs` 拆独立小文件/独立 key。

### 5.5 ○（可选残余）`_positionSub` 每 200ms 唤醒订整个 service 的订阅者
- 位置：`player_service.dart:68`。现存 6 个整 service 订阅者均有去重守卫（`player_bar.dart:107`、`menu_service.dart:63`、`media_control_service.dart:35`、`app.dart:299`、`now_playing_bar.dart:175`）→ 可接受。

### 5.7b 引擎迁移剩余项（2026-09-17 修复后）
- `player_service.dart:497-505`：shuffle 下 `effectiveQueue` 每次访问 O(n) 重建 + `indexOf` → 缓存并按队列/顺序表失效。
- 文档约束：单曲引擎无预加载 → 结构性曲间空白；应在 `docs/AudioEngine-Migration.md` 写明「不得用位置提前量切歌」，避免后人"修"出截尾。

### 5.9 🆕² 加载窗口内按暂停会被静默推翻（高）
- 位置：`player_service.dart:352`（`_shouldPlay = autoPlay`）→ `:361`（`await _engine.load(...)`）→ `:362`（`if (autoPlay) await _engine.play()`，不复查用户意图）。
- 场景：audioplayers 的 `load()`（`setSourceDeviceFile` + `getDuration`）是真实等待窗口（慢盘/大文件更久）；用户「点歌 → 立刻点暂停」时 `pause()` 只把 `_shouldPlay` 置 false，加载返回后第 362 行仍起播。
- 后果：`isPlaying`（= `_shouldPlay`）为 false 但声音在放 —— 播放页/底栏图标、菜单「播放/暂停」标题、Now Playing 的 rate 全显示「已暂停」，再点一次才恢复一致。
- 改法：`:362` 改 `if (autoPlay && _shouldPlay)`（`_shouldPlay` 已是播放意图的唯一权威）；或让 `pause()` 自增 `_loadGeneration`，使在途加载整体作废。

### 5.10 🆕² `playingNotifier` 与 `isPlaying` 双源
- 位置：`player_service.dart:181-184`（初值取 `_engine.isPlaying`）、`:241-247`（只由引擎事件写）；消费方 `now_playing_bar.dart:34-38`、`library_view_model.dart:99`。
- 现状：消费方只把它当「重建触发器」不读值，故目前无症状；但引擎事件缺失（release 抛错、状态未上报）时它会与 `_shouldPlay` 分叉，日后若有人读值就会出 UI 不一致。
- 改法：在 `pause()/stop()/stopPlayback()/_finishQueue` 里与 `_shouldPlay` 一并同步，或删除它、统一用 `_shouldPlay + notifyListeners()`。

## 6. 歌词

### 6.1 两遍匹配误判（已修，2026-09-17 ✅）
- ~~片头多行共用同一时间戳（作词/作曲/编曲）时误判切点，整首歌词被归入翻译段；已加「切点前至少两个不同时间戳」守卫，并在 `lyrics_split_test.dart` 补回归用例。~~

### 6.2 外部 `.lrc` 无缓存，切歌/切翻译开关都重读重解析（低）
- 位置：`lib/core/services/lyrics_view_model.dart:145` + `:171-196`（`splitBilingualLrc` 在 UI isolate 同步跑）；内嵌歌词已有 mtime 缓存（`:199-213`），外部没有。
- 改法：加「路径+mtime → 文本/拆分结果」缓存。

### 6.3 `LyricsViewModel` 启动期即读当前歌歌词（低）
- 位置：`service_locator.dart:234` 构造 → `lyrics_view_model.dart:70-71`（同步 `_onSongChanged()`/`_syncPosition()`）→ `:125` 立刻读盘（`resolveLrcPath :22-31` 用 `existsSync`）。
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

### 8.1 🆕² 睡眠定时到点的 5 秒淡出期间无法取消，且「按播放」会被再次暂停（高）
- 位置：`sleep_timer_service.dart:203-209`（`_notify()` 先 `state.value = null` 再 `await _player.fadeOutAndPause(...)` — UI 立即认为「未激活」，实际还要响 5 秒）、`:135-141`（`cancel()` 首行 `if (!isActive && _timer == null) return;`，即使被调到也不会 `cancelFadeOut()`）。
- 连带：`sleep_timer_button.dart:129-137`（「取消定时」项仅 `active` 时构建）、`AppDelegate.swift:230-232`（原生「取消」项读 `sleepTimerMode != "off"`）→ 淡出期间两个入口都消失/置灰。
- 更糟：淡出期间用户点「播放」→ `togglePlay()` 因 `_shouldPlay == true` 走 `pause()`；用户再点一次播放后，`player_service.dart:723` 尾部的 `if (_shouldPlay) await pause()` 又把刚恢复的播放停掉（表现为「按播放没反应」）。
- 改法：给状态加 `fading` 标志（淡出期间仍算 active，UI/原生菜单据此保留取消入口）；把 `cancelFadeOut()` 提到 `cancel()` 的早退判断之前；`fadeOutAndPause` 尾部的 `if (_shouldPlay) await pause()` 改为只在「本次淡出未被取消/未被重新起播」时执行。

### 8.2 🆕² 倒计时按 tick 递减而非按 deadline
- 位置：`sleep_timer_service.dart:174-182`（`next = current!.remaining! - tickInterval`）。
- 后果：定时器被节流或系统睡眠期间剩余时间不随真实时间推进（醒来仍剩原分钟数），且每次 tick 的调度误差持续累积 —— 与「定 30 分钟就是 30 分钟」的预期不符。
- 改法：`startForDuration` 记 `deadline = DateTime.now().add(duration)`，每次 tick 用 `DateTime.now()` 差值算剩余。

### 8.3 🆕² `notif_attachments/` 只增不减，且同一首歌反复切会重复拷贝
- 位置：`track_notification_service.dart:158-176`（`_copyCoverForAttachment`）：每首歌把封面复制到 `Documents/notif_attachments/cover_<songId><ext>`，先 `delete` 再 `copy`。
- 后果：① 长期使用按曲库规模持续占用沙箱磁盘，**没有任何清理策略**（`cleanupOrphanCovers` 只管 `covers/`）；② 来回切换同一首歌会反复 delete+copy 整份图片。
- 改法：拷贝前比对文件大小/mtime，一致则跳过；在孤儿封面清理（或启动 quickSync）时同步清掉不在库中的 `cover_*` 副本。

### 8.4 🆕² 淡出刚开始就提示「已暂停」，与听感不符
- 位置：`sleep_timer_service.dart:206-209`（`_notify('睡眠定时结束，已暂停')` 在 `fadeOutAndPause` 之前）。
- 改法：提示移到淡出结束之后发，或文案改为「睡眠定时结束，正在淡出…」。

### 8.5 🆕² `PlaybackFeedbackService.stop()` 的注释/文案与实际行为不符
- 位置：`playback_feedback_service.dart:112-127`（注释称「停止会清空队列，底栏随即变成未在播放」），实际调用 `PlayerService.stopPlayback()`（`player_service.dart:650-658`：保留队列与当前曲目，只归零位置）。
- 后果：按 ⌘. 后底栏仍显示当前曲目，与注释/UI 约定不一致，后续维护容易被误判为 bug 或误改。
- 改法：注释与 HUD 文案改为「已停止（保留队列，再播从头开始）」，或让 `stop()` 真正调用会清队列的 `PlayerService.stop()`。

### 8.6 🆕² 通知点击唤回窗口的异常被静默吞掉
- 位置：`track_notification_service.dart:262-270`（`catch (_) {}`）。
- 后果：违反 `docs/ErrorHandling.md` §5「禁止静默」；用户点了横幅但窗口没出现时，日志里查不到痕迹。
- 改法：`catch (e) => AppLogger.warning('Notify', 'Failed to restore main window', e)`。

### 8.7 🆕² 通知「仅后台弹」与设置项文案的语义落差（低）
- 位置：`track_notification_service.dart:118-131`（`presentBanner/presentList/presentAlert = false`，刻意设计）+ `settings_page.dart:331-339`（设置项「切歌时显示系统通知」）。
- 说明：前台不弹是有意为之（窗口可见时用户本就看到底栏），但设置项名没写「仅在后台」，容易被当成「开关失效」。
- 改法：设置项副标题补「仅在窗口不在前台时显示」，或在 `docs/UI-Rules.md` 写明该策略。

## 9. macOS 原生层（2026-09-22 审查新增）

### 9.1 🆕² 原生在主线程同步解码整张封面
- 位置：`macos/Runner/MediaControlsPlugin.swift:118-128`（`NSImage(contentsOfFile:)` + `MPMediaItemArtwork(boundsSize: image.size)`），位于方法通道回调（主线程）。
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
- 位置：`macos/Runner/AppDelegate.swift:208-218`（只比 `off` / `all` / `shuffled`）← `menu_service.dart:176` 推的是 `_player.repeatMode.name`，单曲循环下为 `"one"`（`player_service.dart:520-523` 的 `baseRepeatMode` 才是底层模式）。
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

### 11.2 第 1 批 — 用户可见行为（建议下一轮直接做）

同一主题都是「状态与 UI 说法不一致」，改动小、无架构风险：

1. **8.1** 睡眠定时淡出期间无法取消 + 「按播放」被再次暂停（S）
2. **5.9** 加载窗口内按暂停被静默推翻（S，`:362` 加一行守卫）
3. ~~**9.2** 原生空格键吞掉非文本框的空格（S）~~ ✅ 2026-09-23（与 §10.1 的 Tab 退出口同一批，见 11.1）
4. **4.7** 媒体控制 `setup()` 失败升级成整屏启动失败页（S）
5. **9.4** 单曲循环时播放模式子菜单勾选不同步（S）
6. **4.9** 菜单推送失败后不再重试（S）
7. **8.4 / 8.5 / 8.6** 淡出提示文案、`stop()` 注释、静默 catch（S）

> 建议：8.1 要引入 `fading` 状态，8.2/8.4 都动 `sleep_timer_service.dart` —— 三者放同一次提交，避免反复改同一个文件。

### 11.3 第 2 批 — 有可测收益的性能项

1. **9.1** 原生主线程解码整张封面（M，目前唯一可能明显掉帧的原生热点）
2. **4.8** 菜单每 ~200ms 的 UI 树祖先遍历（S，改订 `uiListenable` + 缓存判定）
3. **8.3** 通知封面副本的重复拷贝与堆积（M）
4. **2.4 / 2.7** 两处全行物化查询改 `selectOnly` 投影（S）
5. **3.5 / 3.7 / 3.8** 扫描与孤儿清理的批量 / 短路（M）
6. **1.5 / 1.6** 底栏填充层与睡眠按钮的重建粒度（S）
7. **6.2 / 6.3** 歌词外部 `.lrc` 缓存与延迟加载（S）
8. **4.2 / 5.3** 日志批量 flush、播放位置独立落盘（S~M）
9. **2.5 / 3.6 / 3.11 / 4.3 / 5.5 / 5.7b** 残余小项（S），可并成一次「清理批次」提交

### 11.4 第 3 批 — 一致性收尾（低风险顺手）

- **8.2** 倒计时按 deadline 计算、**8.7** 「仅后台弹」文案、~~**9.3** `⌘.` 修饰键严格判断~~ ✅（2026-09-23）
- ~~**9.5** `as!` 强转改 `guard let`~~ ✅（2026-09-23）、**4.10** `DetailTopBar` 通道兜底、**5.10** 播放态双源
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

