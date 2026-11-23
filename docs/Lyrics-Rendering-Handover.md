# 歌词渲染性能：交接（fork `flutter_lyric` 之前）

> 本文是**自包含**的：目标是让人在**另一个项目**里 fork `flutter_lyric`、改它的渲染路径时，不用重新做一遍排查。
> 结论、实测数字、代码位置、验证方法都在这里。仓库内的临时探针（`perf_probe.dart`）也一并说明怎么搬。
> 关联文档：[Performance-Optimization.md](./Performance-Optimization.md)、[LyricsParsing.md](./LyricsParsing.md)、[Pitfalls.md](./Pitfalls.md)

⸻

## 0. 一句话结论

**卡顿有两条互不相干的线，别混在一起治：**

| 线 | 触发条件 | 单次代价 | 归属 | 状态 |
|---|---|---|---|---|
| A. 歌词换行 | 每句歌词切换（跟唱时约每 4s 一次） | 换行帧 17–28ms；长句最高 105ms | `flutter_lyric` 的 `LyricPainter` | **本文重点**，待 fork |
| B. 着色器编译 | 每种新页面 / 新效果**本进程首次**出现 | 100–150ms/帧，一串 3 帧 | Skia + Metal 驱动 | 已知（见 §5），暂不处理 |

线 A 与应用代码无关，改 `flutter_lyric` 才有效；线 B 与应用代码也无关，只有换渲染后端才能消——而 Impeller 实测能消掉它，代价却更大（见 §5），所以也不动。

⸻

## 1. 测量环境与口径

| 项 | 值 |
|---|---|
| 机器 | 2018 15" Intel MBP，UHD 630 + Radeon 560X，Retina 2x |
| 系统 / Flutter | macOS / 3.50.0 stable |
| 渲染后端 | **Skia**（`macos/Runner/Info.plist` 里 `FLTEnableImpeller=false`） |
| 抓取方式 | `--dart-define=PERF_PROBE=true` + `AppLogger`（release/AOT 也能读） |
| 对照方式 | profile + `--trace-skia` + DevTools 导出 JSON |

**三个读数口径（重要，读错会得出相反结论）**

- `ui` = `FrameTiming.buildDuration`：build + layout + paint 录制。
- `raster` = `FrameTiming.rasterDuration`：光栅化线程（含 SkSL/驱动编译）。
- `gap` = `FrameTiming.vsyncOverhead`：**不是**"主 isolate 被占住"。帧与帧之间有长空闲时它约等于空闲时长（实测空闲的库页出现过 396ms 的 `gap`，而那一窗 `ui` p50 只有 0.91ms）。
  判断"主 isolate 真的被占"只能看**看门狗测的 `STALL`**（32ms 周期计时器迟到）。

⸻

## 2. 线 A 的实测证据（三组对照）

### 2.1 歌词效果全关 vs 全开（release，播放页跟唱，各 5×10s 窗口）

| 配置 | raster p50 | p90 | max | ≥16.7ms 帧 |
|---|---|---|---|---|
| 效果全开 | 1.31ms | **14.28ms** | **28.46ms** | 0–21 / 窗口 |
| 效果全关¹ | 1.45ms | **2.30ms** | **3.10ms** | **0 / 窗口** |

¹ 关的是「距离模糊 / 行过渡 / 词高亮 / 倒计时」。

**两个推论：**

1. `p50` 几乎不变（1.31 → 1.45），而且关闭后仍是满 60fps 在滚动（每窗口 ≈600 帧）。
   → **每帧固定要做的事（整块文字重绘、词高亮、倒计时）几乎不花钱。**
2. 差异全部落在 `p90` / `max`，也就是**事件型的换行帧**。
   → 换行时那 2–3 层 `saveLayer` 是全部代价。

### 2.2 窗口缩小（效果全开，接近最小尺寸 800×600）

| | 全窗 | 最小窗 |
|---|---|---|
| raster p90 | 14.28ms | 10.90ms（−24%） |
| 单帧换行代价 | 17–28ms | **仍是 17–40ms** |

面积降到约 1/4~1/5，换行帧却没怎么变。
→ **不是像素填充率问题，是"每开一个离屏层"的固定开销。**

这条同时否掉了两个方向：缩小绘制区域、换 Impeller（治不了 `saveLayer` 的结构性开销）。

### 2.3 播放页 vs 库页（profile，同时段）

| 页面 | raster p50 | p90 | ≥16.7ms 占比 | ui p50 |
|---|---|---|---|---|
| 音乐库 | 3–5ms | 4–9ms | 0.5–1% | 0.6ms |
| **播放页（跟唱）** | **13.3ms** | **29.4ms** | **31.6%** | 0.5ms |

差 3–4 倍，且 `ui` 都是 0.5ms 级 → **纯光栅化，且只在歌词可见时出现**。

⸻

## 3. `flutter_lyric` 的渲染路径（花钱的地方）

版本：**4.1.0**（`~/.pub-cache/hosted/pub.dev/flutter_lyric-4.1.0`，下称 `<pkg>`）。

调用链：

```
RenderLyricViewport.paint          <pkg>/lib/src/rendering/lyric_viewport.dart:43
  └─ LyricPainter.paint
       └─ _paintSession            <pkg>/lib/src/rendering/lyric_painter.dart:61
            ├─ 逐可见行：translate + scale
            ├─ layered = opacity < 1 || sigma > 0      :98
            │    └─ canvas.saveLayer(bounds, paint)    :105   ← 换行帧的代价在这
            └─ drawLine → 基础文字 + 高亮
                 ├─ _drawHighlightColors               :121（内部 :291 / :315 还有 saveLayer）
                 └─ LyricWordPainter                    <pkg>/lib/src/rendering/lyric_word_painter.dart
                      ├─ 正常路径：LyricWordRasterCache 图集（drawImageRect + ColorFilter）
                      └─ 边界跨字退化：每字符 saveLayer(ImageFilter.matrix) + clipPath   :104
```

要点：

- **只画可见行**（`session.visibleIndices`），这块没问题。
- **布局有缓存**：`RenderLyricViewport._changed()` 里 `session.needsLayout` 才 `markNeedsLayout()`，否则只 `markNeedsPaint()`；`LyricLayout.compute` 也支持 `onlyIndex`。
  → 挂载时那 62–70ms 的全量 `TextPainter.layout()` 只在首帧，稳态不会再跑。
- **词高亮走图集**（`LyricWordRasterCache`，`toImageSync` 打包成一张图），所以稳态便宜 —— 与 §2.1 的推论一致。

⸻

## 4. fork 候选改动（按收益 / 风险排序）

### 4.1 首选：`sigma == 0` 时不要 `saveLayer`（零视觉风险）

位置：`<pkg>/lib/src/rendering/lyric_painter.dart:98-106`

```dart
final layered = visual.opacity < 1 || sigma > 0;
if (layered) {
  final paint = Paint()..color = colorWithOpacity(const Color(0xFFFFFFFF), visual.opacity);
  if (sigma > 0) paint.imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);
  canvas.saveLayer(bounds, paint);
}
```

改法：`sigma == 0` 时**把 `visual.opacity` 直接乘进要画的颜色/高亮 alpha**，不建层；只有 `sigma > 0`（距离模糊、zoom 过渡）才保留 `saveLayer`。

- 视觉等价性：纯色字形没有自重叠，逐色 alpha 与整层 alpha 结果一致；若某行将来加了描边叠字，需要复查。
- 预期：换行帧 `p90` 从 14.3ms 回到 §2.1 的 2.3ms 量级（即"关掉效果"的水平，但保留行过渡）。

### 4.2 次选：`_coloredMask` 的逐字符层

位置：`<pkg>/lib/src/rendering/lyric_word_painter.dart:104-122`、`:167-190`

- `:104` 每个字符一次 `saveLayer(ImageFilter.matrix)`（为亚像素浮动做切片平移）。
- `:178` / `:187` 是 `_coloredMask` 的 `saveLayer` 与 `saveLayer(srcIn)`。

只在"高亮边界跨字"或开词级 lift/float 时触发，频率低；但如果 4.1 做完还有残余，这里是下一个。

### 4.3 布局：全量 → 可见行 + 缓存

位置：`<pkg>/lib/src/rendering/lyric_layout.dart:26`（`LyricLayout.compute` 对每一行都 `TextPainter.layout()`）

`onlyIndex` 已存在但没被用于"只量可见窗口"。建议按 `(documentRevision, resolvedStyle, viewSize)` 缓存，并对窗口外行用估算高度。
治的是**进播放页挂载歌词栏那一帧的 62–70ms `ui`**，与 4.1 是两件事。

### 4.4 静态层 / 活动层拆开（viewport 层）

`RenderLyricViewport` 目前整块在 `markNeedsPaint()` 后重画全部可见行。可以把它拆成两层：非活动行（换行才变）+ 活动行（逐帧变），活动行约占 1/8 面积。
只在 4.1 实施后仍有残余时再做。

⸻

## 5. 线 B：着色器编译（已知，暂不处理）

**证据**（DevTools 导出、`--trace-skia`、frame 705，raster 149.1ms）：

| 事件 | 耗时 |
|---|---|
| `GrMtlPipelineStateBuilder::finalize` | 142.0ms |
| **`driver_compile_shader`** | **135.5ms** |
| `GrDrawingManager::flush` / `OpsTask::onPrepare`·`onExecute` | 143–145ms |

全会话：**207 次编译事件、累计 377.9ms、散布在 24 个帧**；同一动作在"已经热过"的进程里只有 49ms。
→ **per-process 一次性**，这解释了所有"第一次 112ms / 第二次 16.5ms"的现象。

**Impeller 已验证（2026-11-20，release A/B，窗口 1009×836）**：花屏已消失（原先禁用它的理由不再成立），但性能在两类场景下不可接受，且**成因不同**：

| 场景 | Skia raster p50 / p90 / max | Impeller raster p50 / p90 / max | 性质 |
| --- | --- | --- | --- |
| 主界面 Albums tab 滚动 | **2.27 / 2.90 / 3.69** | 3.15 / 28.06 / 116.2 | **尾巴**：p50 尚可，p90 差 10 倍 |
| 播放页跟唱 | 1.31 / 14.28 / 28.46 | 47.9 / 49.7 / 103 | **底盘**：p50 就超 3 个 vsync |
| 专辑详情页静置 | — | 1.61 / 1.96 / 3.09 | 正常 |
| Songs tab 静置 | 1.9 / 2.3 / 3.1 | 3.83 / 7.94 / 66.7 | 正常 |

- Skia 在 Albums 滚动下 **4 个连续窗口 slow16 全为 0%**（517 / 548 / 578 / 287 帧，满 60fps）
- Impeller 下同场景 slow16 15.6–21.3%，播放页 slow16 **100%**
- 播放页 raster 与窗口面积近似线性（640×520 → 47.9ms，最小窗 → 18.0ms；比值 2.66 vs 面积比 2.8）→ 是**填充率**，不是固定的 per-pass 开销
- 唯一收益：省掉上面那 135ms 着色器编译（专辑详情首帧 112ms → 2ms）

→ 结论：**暂不启用**，`FLTEnableImpeller=false` 保持现状，记录在 [TODO.md](./TODO.md) §2。

→ 若要继续调这条线，方向是**减少层数**（`saveLayer` / 独立 `RepaintBoundary` / per-card layer），与 §4.1 同向；**不是** `impeller-use-sdfs`——圆角填充本身已被排除：Albums tab 是圆角卡片最密集的界面，其 p50 只有 3.2ms。

⸻

## 6. 怎么复现测量

### 6.1 应用内探针（release 可用）

> **探针已在 2026-11-20 按仓库要求拆除**，不再随代码提交。源码（373 行）备份在
> 本会话产物 `files/perf_probe.dart.bak`；需要复现时把它放回
> `lib/core/utils/perf_probe.dart`，再按 §7「★ 接线」一节的 5 处挂回即可。

装备方式：

```bash
flutter build macos --release --dart-define=PERF_PROBE=true
```

输出写在 `~/Library/Containers/<bundle-id>/Data/Documents/logs/app-*.log`，tag 为 `Perf`（应用内「设置 › 日志」也能看）。

| 行 | 含义 |
|---|---|
| `SUMMARY 10.0s frames=… slow16=… slow33=… \| ui p50/p90/max \| raster p50/p90/max \| gap max \| stalls` | 每 10 秒一行 |
| `FRAME … why=gap\|raster\|ui` | 当窗最慢的 5 帧 |
| `STALL 41.2ms overlap=[db.select(38.9ms)]` | **主 isolate 真的被占**（唯一可信判据） |
| `MARK name n=… total=… max=…` | 业务打点（SQL、启动各步、after 阶段） |

注意：`MARK` 只在**10 秒窗口结束时**刷出 —— 跑完别急着关进程，否则最后一段会丢。

### 6.2 对照实验（不需要改代码）

1. **效果熔断**：设置里把「距离模糊 / 行过渡 / 词高亮 / 倒计时」全关，对同一个播放页比 `raster p90`。这条能立刻告诉你"效果层占多少"。
2. **面积对照**：窗口缩到最小再比一次。若 p90 基本不降 → 是层数问题，别去优化面积。
3. **后端对照（Impeller / Skia）**：改 `macos/Runner/Info.plist` 的 `FLTEnableImpeller` 为 `true`/`false`，各自 `flutter build macos --release --dart-define=PERF_PROBE=true` 后对比。判据：探针输出里 `pic=` 一直是 `0.0MB/0` → Impeller 生效。
   - 换后端后**必须重开进程**再测（管线构建是 per-process 一次性的）。
   - 两轮的窗口尺寸要一致，否则不可比（见 §9 第 8 条）。
4. **Skia 事件归属**：`flutter run --profile -d macos --trace-skia` → DevTools Performance → Record → **动作控制在 3 秒内** → 立即 Stop → 立即 Export。
   - 导出**不需要选帧**，整份快照一起打包。
   - **录制中途暂停会在导出里留下事件空洞**（实测出现过 2.77s 空白，导致帧与事件对不上）；一次连续录完再导出。

⸻

## 7. 本仓库当前的工作区状态

**探针已于 2026-11-20 拆除**（`lib/core/utils/perf_probe.dart` 及其 5 处接线全部移除）。
未提交的改动只剩 3 处行为改动 + 文档：

| 文件 | 性质 | 说明 |
|---|---|---|
| `lib/features/library/library_view_model.dart` | 行为 | `safeNotify()` 提前到首帧之前；`quickSync` 等 `endOfFrame` 之后再跑 |
| `lib/core/services/lyrics_view_model.dart` | 行为 | 歌词解析进 `Isolate.run`（带同步兜底） |
| `lib/core/viewmodels/page_view_model.dart` | 行为 | 新增 `isDisposed`（跨帧异步早退用） |
| `docs/Lyrics-Rendering-Handover.md` | 文档 | 本文 |
| `AGENTS.md` | 文档 | 索引加了一行 |
| `docs/Performance-Optimization.md` / `docs/TODO.md` | 文档 | 开工前就已 dirty，本工作未改动其内容 |

试过并已回退的：

- 「版本号延后读取」（`service_locator.dart`）：A/B 无收益，原因见 §8
- 「封面淡入改成按需开启」（`CachedAlbumArt.fadeIn`）：按面积和 ImageCache 两条路估算收益都 <5ms，却带可见的观感改动 —— 属于「改了也测不出来」的改动
- `macos/Runner/Info.plist` 的 `FLTEnableImpeller=true`：仅用于 §5 的 Impeller A/B，已还原为 `false`

### ★ 探针接线（恢复时照这 5 处挂回）

| 文件 | 改什么 |
|---|---|
| `lib/main.dart` | `import 'core/utils/perf_probe.dart';` + `PerfProbe.install();`（在 `ensureInitialized()` 之后） |
| `lib/app/app.dart` | `navigatorObservers` 里加 `if (PerfProbe.available) PerfProbe.observer` |
| `lib/core/database/database.dart` | `create()` 里把 `NativeDatabase(...)` 提成局部变量 `executor`，再 `PerfProbe.available ? executor.interceptWith(_PerfQueryInterceptor()) : executor`；文件末尾加 `_PerfQueryInterceptor` |
| `lib/core/services/song_repository.dart` | `backfillSortKeys` 三个阶段各加一个 `PerfProbe.mark('backfill.songs'/'backfill.albums'/'backfill.artists', …)` |
| `lib/core/services/service_locator.dart` | `_doInitialize()` 各 await 点包 `PerfProbe.asyncScope('startup.*', …)`，末尾 `PerfProbe.mark('startup.total', …)` |

> `library_view_model.dart` 里的 `PerfProbe.asyncScope('library.quickSync'/'scan.folders'/'scan.quick')`
> 只是测量包裹，去掉后行为不变。

**迁移到 fork 项目时**：把 `perf_probe.dart` 整个搬过去，`main.dart` 里 `PerfProbe.install()` 一行即可；`_paintSession` 前后各加一个 `PerfProbe.scope('lyric.paint', …)` 就能直接量到改动的收益。

⸻

## 8. 还没做 / 未定性

| 项 | 现状 |
|---|---|
| 进 / 出播放页每次 ~110ms（5 帧 17–41ms，`ui` 只有 0.3–1.5ms） | **未定性**。候选：首次 shader 编译 + 二次的层重建。需要短录制 + 完整事件的导出 |
| 启动链 | 实测 `startup.total` 100–170ms。**「版本号延后读取」已回退**：A/B 无收益，而且 `startup.settings` 从 4.9–24.9ms 涨到 56.6–89.3ms —— `package_info_plus` 与 `path_provider` 共用同一条平台通道，等待只是被挪了位置，总量不变。`quickSync` 延后保留（对应 [Performance-Optimization.md](./Performance-Optimization.md) §2.2 的待办，未单独量化）。结论：启动没有零星阻塞，只有「首帧前的准备时间」，优先级下调 |
| `backfillSortKeys`（文档 §2.5） | 内部实测 **0.5ms（n=0）**，建议标 ⛔ 失效，不要加 `COUNT(*)` 短路（那是多一条查询） |
| [Performance-Optimization.md](./Performance-Optimization.md) §1.7 的"稳态每帧 raster 18–30ms" | **需要更正**：那是换行帧的数字；稳态 p50 是 1.3ms |
| Impeller 下 Albums tab 滚动 p90 **28ms** / max 116ms（Skia 2.9ms / 3.7ms） | **已决定不深挖**——Impeller 整体放弃（§5）。机制候选：per-card `RepaintBoundary` 的层合成 / `Material(clipBehavior: hardEdge)` 的大裁剪层 / 封面纹理上传。若将来必须上 Impeller，这是第一优先级 |
| `gap` 的语义 | 该文档里凡是把 `gap` 当"主 isolate 阻塞"的表述都要改，改用 `STALL` |

⸻

## 9. 踩过的坑（省一次重来）

1. **`saveLayer` 就是钱**，而且跟面积几乎无关。任何"给大子树加淡入/模糊来掩盖卡顿"的想法，先按"层数"估，不要按面积估。
2. **`asyncScope` 的耗时含等待**，不能当"主 isolate 被占"；看门狗 `STALL` 才是。
3. **`FrameTiming.vsyncOverhead` 在空闲期 ≈ 空闲时长**（不是阻塞）。启动首帧那个 100–175ms 的 `gap` 就是"首帧前的准备时间"。
4. **DevTools 导出有事件空洞**（暂停录制导致），表现是"多数帧对不上事件"。短录 + 立即导出。
5. **第一直觉容易落到"封面解码"上**：全程 `drawTextBlob` 3919 次 vs `drawImage` 349 次，图片从来不是主力。
6. **探针的 `MARK` / `STALL` 是「每 10 秒窗口结束时」统一刷出的**，同一批日志的时间戳完全相同 —— 不能用日志时间戳判断两件事的先后。要判先后，得临时加一行 `AppLogger.info` 或自己记单调时钟。
7. **"第二次就快了"不一定是缓存**：可能是 ImageCache（`wasSynchronouslyLoaded`）、也可能是 driver 已编译过 pipeline。要分清得看 §5 那种 trace。
8. **探针不记窗口尺寸，跨轮对比会失效**。窗口面积直接决定 raster 段，而 `SUMMARY` 行里没有尺寸。要么每次记录窗口大小，要么只跟同一轮里的其它窗口对比。`mainWindowFrame`（`~/Library/Containers/<bundle-id>/Data/Library/Preferences/<bundle-id>.plist`）只能查到**当前**尺寸，查不到跑测时的。
9. **`pic=` / `layer=` 是 Skia 的光栅缓存计数**，Impeller 下恒为 `0.0MB/0` —— 这反而是个现成的后端判据：看到它一直是 0，就说明 Impeller 生效了。
