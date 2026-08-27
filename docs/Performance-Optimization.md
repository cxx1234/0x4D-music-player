# 性能与待优化项清单

> 删除线 = 已完成；其余为待办。详细完成记录见 git 提交与仓库记忆。
> 最后更新：2026-08-27

## 1. 渲染 / UI 类

- ~~P1 高频重建削减（播放页局部化、`uiListenable`、进度条自订阅、`PlayQueue.songs` 缓存视图）~~
- ~~P2 封面降采样解码（`cacheWidth` + `gaplessPlayback`）~~

### 1.1 搜索过滤结果未缓存
- 位置：`library_page.dart:85-99` 及 album/artist/playlist 同类 getter。
- 改法：query 不变时缓存过滤结果，变化才重算。

### 1.2 全项目 0 处 `RepaintBoundary`
- 位置：播放页封面/歌词区、`NowPlayingBar`、网格卡片封面。
- 改法：关键区域加 `RepaintBoundary`（勿过度隔离致合成层爆炸）。

### 1.3 歌手详情全表拉专辑
- 位置：`artist_page.dart:217-220`。
- 改法：按 `album_id` 定向查询（同 `getArtistStats` 聚合思路）。

### 1.4 `NowPlayingBar` 仍订阅整个 PlayerService
- 位置：`now_playing_bar.dart:22-23`。
- 关联：底栏「按播放进度填充」功能正好需要 `positionStream`。
- 改法：改订 `currentSongNotifier`+`playingNotifier`，进度填充部分单独订 `positionStream`。

---

## 2. 启动 / 数据层类

- ~~P3 DB schema v6（7 索引）+ WAL + 队列恢复批量查询~~

### 2.1 启动路径串行阻塞
- 位置：`service_locator.dart:137-169` `_doInitialize()`。
- 改法：`Future.wait` 并行独立步骤（settings/DB 开库、backfill、restoreQueue、sandbox）。

### 2.2 每次启动全盘遍历阻塞首屏
- 位置：`library_view_model.dart:117`。
- 改法：先加载歌曲列表再后台 quickSync。

### 2.3 数据库跑主 isolate
- 位置：`database.dart:51` `create()`。
- 前置：WAL 已开。风险：中（需全量测试 + 真实库验证）。
- 改法：`createInBackground`/`readPool`。

### 2.4 `getExistingFileStats` 拉全行
- 位置：`database.dart:124`。
- 改法：投影 `file_path/last_modified_ms/file_size` 三列。

### 2.5 `backfillSortKeys` 每次启动全表扫
- 位置：`song_repository.dart:150`。
- 改法：先 `COUNT` 判断是否为 0，或迁移后一次性标记。

### 2.6 watch 流全是死代码
- 位置：`database.dart` 6 个 `watch*` 方法。
- 改法：清理，或改用 drift 流式更新替代手动 reload。

## 3. 扫描 / 元数据类（全部完成）

- ~~3.1 元数据解析并发 + Isolate（受限并发 worker 池 + 100ms 进度节流）~~
- ~~3.2 变化检测移后台 isolate（`detectChangedFiles` + `Isolate.run`；⚠️ 闭包勿捕获 UI 回调，防 unsendable）~~
- ~~3.3 扫描事务查询去重（artist/album 批量缓存 + dateAdded 批量）~~
- ~~3.4 文件夹并行遍历（`Future.wait`）~~

---

## 4. 后台 / 媒体控制类

### 4.1 每秒重读封面文件 + 解码
- 位置：`media_control_service.dart:42-49` + `MediaControlsPlugin.swift:104-122`。
- 改法：仅切歌传封面，位置用独立轻量更新（只更新 `ElapsedPlaybackTime`）。

### 4.2 日志每行 flush
- 位置：`logger.dart:222-223`。
- 改法：批量缓冲 + 周期 flush（保持崩溃前落盘语义）。

## 5. 播放器 / 持久化类

- ~~P4 写盘防抖（队列 debounce + 串行写链 + 生命周期 flush、音量拖动结束落盘）~~
- ~~5.2 封面缓存扩展名不一致~~

### 5.1 大队列 `setAudioSources` 一次性构建
- 位置：`player_service.dart:377`。
- 改法：分批 `addAudioSources` + 加载反馈。

## 6. 用户自规划功能

- 全局底栏「按播放进度填充」效果（可顺带解决 1.4）。

## 0. 优先级建议

1. **Release 前**：第 6 节（F2、F4）+ 第 7 节底栏进度填充（顺带解决 1.4）。
2. **低风险顺手**：1.1、1.2、1.3、2.4、2.5、2.6、4.1、4.2。
3. **第二轮架构优化**：2.1、2.2、2.3、5.1。
