# 错误处理与日志约定

> 本文档是「约定 + 索引」,不是代码副本。修改错误处理逻辑时请同步更新本文,避免与实现脱节。

⸻

## 1. 分级模型

| 级别 | 含义 | UI 策略 | 日志级别 | 典型示例 |
|---|---|---|---|---|
| **Fatal** | 应用不可用,无法恢复 | 全屏启动错误页 + 重试 | `fatal` | `ServiceLocator.initialize()` 失败、未捕获异步异常 |
| **Error** | 单次操作失败,用户需感知 | SnackBar / 横幅 | `error` | 播放失败、M3U 导出/导入失败 |
| **Warning** | 部分成功,已自动降级 | 汇总提示或不提示 | `warning` | 扫描单文件解析失败、队列保存失败 |
| **Info** | 正常流程关键节点 | 无 | `info` | 启动完成、扫描完成 |

判定方法:用户是否能感知 → 能则 Error(提示 + error 日志),不能但异常发生了 → Warning(降级 + warning 日志)。

⸻

## 2. 日志约定

* **唯一出口**:`AppLogger`(`lib/core/utils/logger.dart`)。**业务日志禁用 `debugPrint`**,一律走 AppLogger。
* **位置**:`{appDocDir}/logs/app-YYYY-MM-DD.log`(与 `music_library.db` 同根)。
* **轮转**:按天分文件;启动时 `AppLogger.pruneOldLogs()` 保留 7 天;单文件超 5MB 截断。正常使用总量 KB 级,无需人工清理。
* **格式**:每行 `yyyy-MM-dd HH:mm:ss.SSS [级别定宽5] [tag定宽10] message`;`error`/`fatal` 追加异常与堆栈(缩进两空格)。
* **消息语言**:英文(与堆栈统一)。
* **tag 集合**:`App` / `Startup` / `Player` / `Scan` / `Sandbox` / `DB` / `Cache` / `M3U` / `Settings` / `FolderWatch` / `Queue` / `Zone` / `Flutter` / `Platform`。
* **测试注入**:`AppLogger.setLogDirectory(dir)` / `flushPending()` / `dispose()`(`@visibleForTesting`);日志解析逻辑见 `test/log_page_test.dart`。

⸻

## 3. 全局兜底(不再有静默崩溃)

| 兜底 | 位置 | 行为 |
|---|---|---|
| `runZonedGuarded` | `lib/main.dart` | 未捕获异步异常 → `fatal` 日志 |
| `FlutterError.onError` | `lib/main.dart` | `fatal` 日志;debug 保留红屏,release 由 ErrorWidget 接管 |
| `platformDispatcher.onError` | `lib/main.dart` | `fatal` 日志后吞掉,不终止应用 |
| `ErrorWidget.builder` | `lib/main.dart` | 构建期错误 → 轻量纯色兜底视图 |
| `StartupErrorPage` | `lib/app/startup_error_page.dart` | 启动失败全屏错误页(重试 + 复制详情) |
| `ServiceLocator.resetInitialization()` | `lib/core/services/service_locator.dart` | 清幂等缓存,供错误页重试 |
| `_PlaybackErrorConsumer` | `lib/app/app.dart` | 全局消费播放错误 → SnackBar(任意页面可见) |
| 日志查看页 | `lib/features/settings/log_page.dart` / `log_detail_page.dart` | 读 `logs/` 按行展示,点击进详情。**未接入导航**(设置页 TODO) |

⸻

## 4. 各模块错误点索引

| 模块 | 错误场景 | 处理位置 | 级别 / 行为 |
|---|---|---|---|
| 播放 | 文件加载/播放失败 | `player_service.dart`(`playFromList`/`play`/`next`/`previous`/`jumpTo`/`addToQueue`) | `error` 日志;自动跳下一首,连续 3 次停止(`_kMaxConsecutiveErrors=3`) |
| 播放 | 队列动态 API 失败(`addAll`/`removeAt`/`insertAll`/`move`) | `player_service.dart` | `warning` + 回退 `_rebuildSequence` |
| 扫描 | 单文件元数据解析失败 | `metadata_service.dart` `parseAll` | `warning`(每文件一条)+ 降级为文件名条目 |
| 扫描 | 目录不存在/不可读 | `library_scanner_service.dart` `_collectAudioFiles` | `warning` + 计入 `errorDetails` |
| 扫描 | 扫描结束汇总 | `library_scanner_service.dart` `scanFolders` | 聚合 `error`「N failure(s)」 |
| 扫描 | 快速同步失败 | `library_view_model.dart` `_quickSync` | `warning` |
| 队列 | 恢复失败 | `play_queue.dart` `restoreQueue` | `warning` + 降级空队列 |
| 队列 | 保存失败 | `play_queue.dart` `_saveToJson` | `warning` |
| M3U | 导出写文件失败 | `playlist_io.dart` `exportPlaylistToFile` | `error` + SnackBar「导出失败」 |
| M3U | 导入读文件失败 | `playlist_io.dart` `importM3uFromFile` | `error` + SnackBar「导入失败」 |
| 封面 | 删除缓存失败 | `album_art_cache_service.dart` `deleteArt` | `warning` |
| 封面 | 保存专辑封面失败 | `song_repository.dart`(两处) | `warning` |
| 文件夹监视 | 新文件/修改解析失败 | `folder_watcher_service.dart` `_onFileAdded`/`_onFileModified` | `warning` |
| 文件夹监视 | 移除处理失败 | `folder_watcher_service.dart` `_onFileRemoved` | `warning` |
| 沙箱 | bookmark 解析 / 读探测失败 | `service_locator.dart` + `sandbox_service.dart` | `warning` + 横幅引导重新授权 |
| 启动 | 服务初始化失败 | `app.dart` `_initializeServices` | `fatal` + 启动错误页 |

⸻

## 5. 新增错误处理的检查清单

新增一个可能抛异常的调用时:

1. **定性**:用户能否感知?能 → Error(UI 提示 + `error` 日志);不能但异常发生了 → Warning(降级 + `warning` 日志)。
2. **兜底**:不确定是否要局部处理 → 交给全局 `runZonedGuarded` 兜底。
3. **保留异常**:用 `catch (e)` 或 `catch (e, s)`,调用 `AppLogger.warning/error/fatal(tag, 英文消息, e, s)`。
4. **禁止静默**:不要用 `catch (_)` 吞掉异常——否则日志查看页无迹可查。
