# 性能与待优化项清单

> 删除线 = 已完成；其余为待办。⛔=已失效/不再适用；🆕=2026-09-17 审计新增。
> 最后更新：2026-09-17（行号已按当日代码重校）

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

## 8. 优先级建议

1. ~~**立即（数据/状态风险）**：2.9（扫描根失败误标）、2.10（LIKE 未转义）、3.10（force purge 误删）、5.4/5.8（settings 写盘）~~ —— 2026-09-17 已全部修复 ✅
2. **发布前必须**：R1、R2、R3、R9；`docs/TODO.md` 其余发布项（Windows 最小尺寸/SMTC、菜单栏勾选）。
3. **中风险（建议排期）**：3.6、5.7b。
4. **低风险顺手**：2.4、2.6、2.7、3.5、3.7、3.8、4.2、4.3、5.3、6.2、6.3、R4、R10、R12。
5. **第二轮架构**：2.1、2.2、2.3、2.8、R7、R8。

