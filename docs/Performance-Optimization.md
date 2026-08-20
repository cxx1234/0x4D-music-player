# 性能与待优化项清单

> 登记本仓库**尚未处理**的优化项。已完成项见 git 提交记录与 `docs/TODO.md`。
> 最后更新：2026-08-20（基于 2026-08-19 三轮代码调研 + 性能优化四阶段收尾后复核）

## 状态总览

- ✅ **已完成（2026-08-19，commit `ec1aa7a`，v0.1.0+37）**：
  - P1 高频重建削减（播放页局部化、`uiListenable`、进度条自订阅、`PlayQueue.songs` 缓存视图）
  - P2 封面降采样解码（`cacheWidth` + `gaplessPlayback`）
  - P3 DB schema v6（7 索引）+ WAL + 队列恢复批量查询
  - P4 写盘防抖（队列 debounce + 串行写链 + 生命周期 flush、音量拖动结束落盘）
- ⏳ **本文件登记以下剩余项**，按类别与优先级排列。

---

## 1. 渲染 / UI 类（低风险，收益中）

### 1.1 搜索过滤结果未缓存
- **问题**：`_filteredXxx` getter 每次 build 都 O(n) 重扫全量列表。
- **位置**：`lib/features/library/library_page.dart:85-99`；album/artist/playlist 页同类 getter。
- **收益**：几千首曲库下每次重建省一次全量扫描；页面重建频率低，收益一般。
- **改法**：query 不变时缓存过滤结果，query 变化才重算。

### 1.2 全项目 0 处 `RepaintBoundary`
- **问题**：无隔离重绘层，滚动时封面/墨水高亮引发大范围重绘。
- **位置**：建议加到播放页封面/歌词区、`NowPlayingBar`、网格卡片封面、正在播放图标。
- **收益**：滚动流畅度提升（重绘区域缩小）。
- **风险**：低；注意不要过度隔离导致合成层爆炸。

### 1.3 歌手详情全表拉专辑
- **问题**：`_load()` 用 `Future.wait([getAllAlbums(), getSongsByArtist])` 为派生该歌手专辑而全表拉取所有专辑，再内存过滤。
- **位置**：`lib/features/artist/artist_page.dart:217-220`。
- **收益**：曲库大时每次进歌手详情省一次全表查询。
- **改法**：改为按 `album_id` 定向查询该歌手涉及专辑（可用 `getArtistStats` 同款聚合思路）。

### 1.4 `NowPlayingBar` 仍订阅整个 PlayerService
- **问题**：`ListenableBuilder(listenable: player)`，播放中每 ~200ms 重建整条底栏（含封面 `Image.file`），但底栏不显示进度。
- **位置**：`lib/features/shell/now_playing_bar.dart:22-23`。
- **关联**：用户计划给底栏做**「按播放进度填充」效果**，正好需要 `positionStream`。
- **改法**：改订 `Listenable.merge([currentSongNotifier, playingNotifier])` + 进度填充部分单独订 `positionStream`。

---

## 2. 启动 / 数据层类（收益中-高，风险中）

### 2.1 启动路径串行阻塞
- **问题**：settings 加载、DB 开库、`backfillSortKeys`、`restoreQueue`、sandbox 恢复全部 `await` 串联，本可并行。
- **位置**：`lib/core/services/service_locator.dart:137-169` `_doInitialize()`。
- **收益**：启动更快（尤其首次/大库）。
- **改法**：`Future.wait` 并行独立步骤（settings 与 DB 开库独立；backfill 与 restoreQueue 独立；sandbox 恢复独立）。

### 2.2 每次启动全盘遍历阻塞首屏
- **问题**：`initialize()` 先 `await _quickSync`（递归目录遍历 + 全表 diff）再 `_loadSongs()`，歌曲列表首帧被整个扫描阻塞。
- **位置**：`lib/features/library/library_view_model.dart:117`。
- **收益**：启动「感知延迟」最大头之一。
- **改法**：先加载歌曲列表再后台 quickSync；或首次启动跳过、仅扫描时全量 diff。

### 2.3 数据库跑主 isolate
- **问题**：`NativeDatabase` 非 `createInBackground`，大查询在 UI 事件循环执行会卡帧。
- **位置**：`lib/core/database/database.dart:51` `create()`。
- **收益**：`getAllSongs`/`getArtistStats` 等大查询移出 UI 线程。
- **前置**：WAL 已开（`createInBackground`/`readPool` 官方要求 WAL 生效）。
- **风险**：中——涉及连接迁移，需全量测试 + 真实库验证。

### 2.4 `getExistingFileStats` 拉全行
- **问题**：只需 `file_path/last_modified_ms/file_size` 三列，现 `select(songs)` 拉整行。
- **位置**：`lib/core/database/database.dart:124`。
- **收益**：扫描每次 quickSync 省内存/IO；低。

### 2.5 `backfillSortKeys` 每次启动全表扫
- **问题**：3 条 `..._sort_key IS NULL` 无索引查询，每次启动白做。
- **位置**：`lib/core/services/song_repository.dart:150`。
- **改法**：先 `SELECT COUNT(*)` 判断是否为 0；或迁移后写一次性标记。

### 2.6 watch 流全是死代码
- **问题**：`watchAllSongs`/`watchAllAlbums`/`watchAllArtists`/`watchSongsByAlbum`/`watchSongsByArtist`/`watchAllPlaylists` 无任何 UI 调用点。
- **位置**：`lib/core/database/database.dart:68/283/332/317/358/378`。
- **收益**：清理或改用 drift 流式更新替代「手动 reload」，后者能减少跨页刷新代码。

---

## 3. 扫描 / 元数据类（收益高，风险中-高，曲库量大时最明显）

> ⚠️ **前置说明（2026-08-19 确认）**：`audio_metadata_reader` 切换在 **`metadata-reader-test` 分支**；当前 **`dev` 仍用 `metadata_god`**（原生 FFI、串行解析、0 处 `Isolate.run`）。以下 C1/C2 的改法应以 dev 现状为基线，或等 `metadata-reader-test` 合并后再做。

### 3.1 元数据解析全串行、无 Isolate
- **问题**：`parseAll` 逐文件 `await parse`；全项目 **0 处 `Isolate.run`**。
- **位置**：`lib/core/services/metadata_service.dart:74`。
- **收益**：大批量扫描提速（并发 + 移出 UI isolate）。
- **改法**：并发解析（限制并发数）+ `Isolate.run`（metadata-reader-test 分支已有此思路）。

### 3.2 变化检测用同步 `FileStat.statSync`
- **问题**：全量扫描对每首已存在文件做同步磁盘 I/O，在 UI isolate 上会卡。
- **位置**：`lib/core/services/library_scanner_service.dart:164`。
- **改法**：改异步 `stat()` 或搬 isolate。

### 3.3 扫描事务内每歌 ~4 次查询
- **问题**：`insertOrUpdateFromScan` 事务内每首歌约 4 次查询（artist/album 查找 + 按路径查 + insert）。
- **位置**：`lib/core/services/song_repository.dart:200`。
- **改法**：artist/album 先内存缓存去重。

### 3.4 文件夹串行遍历
- **问题**：`dir.list(recursive: true)` 逐文件夹串行 await。
- **位置**：`lib/core/services/library_scanner_service.dart:117`。
- **改法**：文件夹之间可并行。

---

## 4. 后台 / 媒体控制类（收益中，风险低）

### 4.1 每秒重读封面文件 + 解码
- **问题**：播放中每秒 `_pushNowPlaying()` → 原生每秒重读封面 `NSImage` + 整份 `nowPlayingInfo` 替换；封面播放中不变却每秒重复解码。
- **位置**：`lib/core/services/media_control_service.dart:42-49` + `macos/Runner/MediaControlsPlugin.swift:104-122`。
- **改法**：仅切歌时传封面，位置用独立轻量更新（只更新 `ElapsedPlaybackTime`）。

### 4.2 日志每行 flush
- **问题**：单 `IOSink` + 每行一次 `flush()`（无批量缓冲），错误风暴时有额外 syscall。
- **位置**：`lib/core/utils/logger.dart:222-223`。
- **改法**：批量缓冲 + 周期 flush；注意保持崩溃前落盘语义。

---

## 5. 播放器 / 持久化类（收益中）

### 5.1 大队列 `setAudioSources` 一次性构建
- **问题**：首次「播放全部」几百上千首：主 isolate O(n) 构建 + 原生一次性建 n 个 `AVPlayerItem`（`useLazyPreparation` 已避免全量文件 I/O，但队列构建仍是 upfront）。
- **位置**：`lib/core/services/player_service.dart:377`。
- **改法**：分批 `addAudioSources` + 加载反馈（loading 状态）。

### 5.2 封面缓存扩展名不一致
- **问题**：`getAlbumArtPath` 恒返回 `.jpg`，但 `saveAlbumArt` 按 mime 存 `png/webp/gif` 扩展名 → 潜在读取不到。
- **位置**：`lib/core/services/album_art_cache_service.dart:77/96`。
- **改法**：统一扩展名（保存时记录真实扩展名，或读取时按 mime 探测）。

---

## 6. 发布前待办（非性能，但影响 Release）

- **F2 日志查看页未接入导航**：`LogPage`/`LogDetailPage` 已实现，设置页仍是 TODO 占位（`lib/features/settings/settings_page.dart`）。接入方式：`Navigator.push(MaterialPageRoute(builder: (_) => const LogPage()))`。
- **F4 Windows 窗口最小尺寸未做**：macOS 已设 `contentMinSize`；Windows 需 `WM_GETMINMAXINFO` 方案（`window_manager` 为备选）。
- **macOS 音乐文件夹权限优化**（`docs/TODO.md` 已登记，方案 A/B/C）：降低对「手动去系统设置添加」的依赖。
- **菜单栏项与键盘快捷键**（如 Cmd+Shift+M 之类）：`AppDelegate` 侧待办。

---

## 7. 用户自规划功能（待做）

- **全局底栏「按播放进度填充」效果**：`NowPlayingBar` 需订 `positionStream` 做进度填充，可顺带解决 1.4 的整服务订阅问题。

---

## 8. 优先级建议

1. **Release 前**：第 6 节发布前待办（尤其 F2 日志页接入、F4 窗口最小尺寸）；1.4 + 第 7 节底栏进度填充（顺带性能收益）。
2. **低风险顺手**：1.1、1.2、1.3、2.4、2.5、2.6、4.1、4.2、5.2。
3. **第二轮架构优化**（收益高、改动面大）：2.1、2.2、2.3、3.1、3.2、3.3、3.4、5.1——建议 Release 后专门一轮，且 3.x 等 `metadata-reader-test` 分支合并后再动。
