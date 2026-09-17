# 播放引擎抽象与 audioplayers 迁移计划

> 状态：**评估完成，未实施**
> 基线：`dev @368b05d`（工作区干净，`flutter test` **198 通过**，耗时 ~38s）
> 相关文档：`Architecture.md` §Audio Architecture、`Rules.md` §Audio / §Git / §Dependencies

---

## 0. 背景

### 0.1 痛点

当前 `PlayerService`（`lib/core/services/player_service.dart`，960 行）直接包装 `just_audio` 的 `AudioPlayer`，因此**同一份队列存在两份副本**：

| 副本 | 位置 | 谁维护 |
|---|---|---|
| 逻辑队列（唯一真相，含 UI 依赖的索引/当前曲/持久化） | `PlayQueue` | 应用层 |
| 引擎队列（`AVQueuePlayer` 的 item 列表 + shuffle order + currentIndex） | just_audio 内部 | 引擎 |

为了保持两者一致，`PlayerService` 里长出了一批补丁代码：`_sequenceLoaded` 惰性加载标志、`_rebuildSequence` 兜底、`_handlingQueueEnd` 收尾防护、`_reconcile` 每秒对账 watchdog、`_lastEventIndex` 回绕检测、`effectiveIndices` 三处换算、四个动态队列 API 的 `try/catch → 回退重建`。这些补丁之间互相牵制，是历次 bug（队尾收尾、续播位置被 0 覆盖、索引分叉）的温床。

### 0.2 项目既有约定（本计划的主要依据）

`Rules.md` §Audio：

> * Never call playback libraries directly from Widgets.
> * Always use PlaybackService.
> * **AudioEngine should remain replaceable.**

`Architecture.md` §Audio Architecture 给出的目标分层：

```
UI → PlayerViewModel → PlaybackService → AudioEngine → Platform implementation
```

> The UI must never directly call just_audio or any platform API.
> **This abstraction allows replacing the playback engine in the future.**

即：**「引擎可替换」是本项目已经承诺的架构，`AudioEngine` 这一层目前缺位。** 本次迁移正好是补齐它的契机。

### 0.3 目标 / 非目标

**目标**

1. 引入 `AudioEngine` 抽象层，`PlayerService` 只依赖接口（消除"两套队列"的结构性成因）。
2. 队列推进 / 随机排列 / 重复模式 / 队尾收尾等**纯逻辑上移到 `PlayerService`**，可用 FakeEngine 单测。
3. 在此前提下评估并落地 `audioplayers` 实现。

### 0.4 关键约束（2026-09-16 修订）

**「消除两套队列」与「保住 gapless」在当前技术选型下互斥。**

* 要保住 gapless，就必须让引擎持有队列（just_audio 的 `AVQueuePlayer` + 预取），"引擎镜像队列"因此永远存在。
* 要消除镜像，接口就必须单曲化，just_audio 的队列能力随之作废 —— **在 just_audio 上做单曲化是纯退化**（白丢 gapless + 预取，还要自己写推进逻辑）。
* 结论：**取消"先在 just_audio 上抽接口并合入 dev"的中间阶段**。`dev` 全程不失去 gapless；单曲化只发生在本次迁移分支内部，合入 `dev` 的前提是迁移整体通过验收。

**Q1 已确认（2026-09-16）**：使用者曲库中没有"非 gapless 不可"的连续型专辑（混音 / 现场 / 古典乐章衔接）→ **gapless 不作为本次迁移的通过门槛**。

> 仍须在 Phase 4 检查两个**与专辑类型无关**的项：
> ① **尾部截断**（上一首结尾被吃掉）—— 任何专辑都可能察觉。**注意：这并非 audioplayers 的已知缺陷**（darwin 的 completion 来自系统的 `AVPlayerItemDidPlayToEndTimeNotification`，音频播完之后才到，它本身不会提前砍尾）。它是**单曲架构引入的风险**：切歌时机改由我们的 Dart 逻辑判定 → ⚠️ **禁止用"位置接近时长"的提前量来切歌**（那正是为了掩盖间隙而截尾的写法，与附录 C 的双实例是同一类陷阱）；
> ② **编码 padding 未裁剪**（每首边界多出 ~20–50ms 垫音）。

**非目标**

* 不改 UI 层（含 `player_page` / `queue_view` / `player_bar` / 底栏）。
* 不改系统媒体控制（`MediaControlService` + `macos/Runner/MediaControlsPlugin.swift`）。
* 不改歌词（`LyricsViewModel` 只依赖 `currentSongNotifier` + `positionStream`）。
* 不改数据库/扫描/播放列表/M3U。
* 不追求"证明 audioplayers 更好"——**允许结论是放弃**。

---

## 1. 现状：引擎耦合点清单

`lib/` 中只有 **2 个文件** import just_audio：

| 文件 | 耦合内容 | 影响 |
|---|---|---|
| `lib/core/services/player_service.dart` | `AudioPlayer`、`AudioSource.file`、`setAudioSources` / `addAudioSources` / `removeAudioSourceAt` / `insertAudioSources` / `moveAudioSource`、`playbackEventStream` + `processingState`、`positionStream` / `durationStream` / `playingStream`、`LoopMode`、`effectiveIndices` / `shuffle()` / `setShuffleModeEnabled`、`seek(index:)` / `seekToNext` / `seekToPrevious`、`stop()` 语义、`dispose()` | 重写主体 |
| `lib/core/services/service_locator.dart` | `JustAudioPlatform.instance.disposeAllPlayers()`（热重启幽灵播放器 hack） | 迁移后可删 |

**完全不受影响**：`PlayQueue`、`MediaControlService`、`LyricsViewModel`、`MenuService`、`PlayerViewModel`、全部 UI、沙箱 bookmark、数据库、SPM 构建。

> 对外契约中**必须保持语义不变**的三个 shuffle API（`queue_view.dart` 依赖）：
> `effectiveQueue` / `effectiveIndex` / `logicalIndexForEffective`。

---

## 2. 能力差距（audioplayers 6.8.1）

| 现在用的（just_audio） | audioplayers | 结论 |
|---|---|---|
| `setAudioSources(..., initialIndex:, initialPosition:)` | `setSource(DeviceFileSource)` + `seek` + `resume` | 只能单曲 |
| `addAudioSources` / `removeAudioSourceAt` / `insertAudioSources` / `moveAudioSource` | **无** | 退化为纯 `PlayQueue` 操作（✅ 本次收益） |
| `seek(Duration.zero, index:)` / `seekToNext` / `seekToPrevious` | **无** | 自己实现（切 source） |
| `LoopMode.off/one/all` | `ReleaseMode.stop/loop/stop` | 只有 one 可映射，off/all 自己判 |
| `setShuffleModeEnabled` + `shuffle()` + `effectiveIndices` | **无** | 自己维护排列 |
| `playbackEventStream`（原子带 `currentIndex` + `processingState`） | `eventStream` / `onPlayerStateChanged` / `onPlayerComplete` | 事件模型不同，需重写状态机 |
| `positionStream`（Dart 端 ~200ms） | `onPositionChanged`（默认**每帧**更新） | 必须换 `TimerPositionUpdater(200ms)` |
| `durationStream` | `onDurationChanged` / `getDuration()`（`Duration?`） | 类似 |
| `playing` / `playingStream` | `state == PlayerState.playing` / `onPlayerStateChanged` | 类似 |
| `stop()`（暂停 + 保留位置）、`dispose()` | `stop()`（**位置归零**）、`release()`（释放解码器） | ✅ 反而更贴合我们的语义 |
| `disposeAllPlayers()` 平台接口 hack | `AudioPlayer.global`；6.2.0 起 hot restart 自动清理 | ✅ 可删 hack |
| macOS 使用 `AVQueuePlayer` + 预取下一项（`TREADMILL_SIZE=2`）+ `actionAtItemEnd=Advance` | 单个 `AVPlayer` + `replaceCurrentItem` | ⚠️ **丢失 gapless 与预加载** |

**关键退化：gapless。** just_audio 的 darwin 实现在 `AudioPlayer.m` 里维护 `AVQueuePlayer` 队列并预取（`TREADMILL_SIZE 2`、`playerItem2` 翻转用于 loop），切歌是无缝的；audioplayers 的 darwin 实现（`WrappedMediaPlayer.swift`）是单 `AVPlayer` + `replaceCurrentItem`，且 `_completePrepared` 在设新源前会先 `stop()`/`release()`，**曲间必然有空隙**。

### 2.1 「间隙」的三种来源（判定标准）

| 类型 | 来源 | 正常吗 | 听感 |
|---|---|---|---|
| ① 文件尾部自带静音 | 内容本身（母带就有） | ✅ 正常 | 听不出——那段本来就该静 |
| ② 编码 padding 未裁剪 | 编解码器（MP3 帧 1152 采样 ≈ 26ms、AAC 1024 ≈ 23ms；头尾各有 encoder delay / padding） | ❌ 实现缺陷 | 内容连续时可听出（几十 ms"垫音"） |
| ③ 解码管线重建的空白 | 引擎换文件：`stop → release → setSource → await prepared → resume` | ❌ 实现缺陷 | 内容连续时最明显 |

②③ 合称 gapless 问题。**只有当「上一首结尾」与「下一首开头」在内容上连续时才暴露**（混音专辑 / 现场掌声 / 古典乐章 / 刻意 seamless 衔接 / 结尾渐弱直接切入）；流行专辑边界本就是静音，听不出差别。

**反向风险**：②③ 的另一种表现是**尾部被截断**（最后一个音被吃掉）——这一项与专辑类型无关，必须单独验证。

---

## 3. 分支与提交策略

**单分支 `feature/audioplayers-engine`**（从 `dev` 切出），内容依次为：抽接口 → 队列逻辑去引擎化 → audioplayers 实现。

**`dev` 全程不受影响。** 分支内部会先做出一个"单曲化的 `JustAudioEngine`"用于**隔离验证**（先确认队列逻辑重构本身没坏，再换引擎），但它**不会合进 `dev`** —— 因为在 just_audio 上单曲化等于主动丢掉 gapless（见 §0.4）。合入 `dev` 的前提是迁移整体通过 Phase 4 验收。

A/B 对比改为**两个构建产物**对比，而不是运行时切换引擎：

| 产物 | 来源 | 用途 |
|---|---|---|
| 基线 | `dev` 构建（just_audio + 原生队列，当前 gapless） | 对照：曲间表现、切歌延迟、错误时序 |
| 实验 | 本分支构建（audioplayers + 单曲引擎） | 同上 |

放弃成本：**整条分支丢弃即可，`dev` 无需回滚。**

---

## 4. 目标接口草案

```dart
/// 单曲播放引擎抽象。**刻意不包含队列**——队列是 PlayQueue 的职责。
abstract class AudioEngine {
  /// 加载并（可选）定位到 [initialPosition]；实现方需记录 [path] 以避免重复加载。
  Future<void> load(String path, {Duration? initialPosition});

  Future<void> play();
  Future<void> pause();

  /// 停止并**把位置归零**（与 just_audio 的 stop 语义不同，适配器负责转换）。
  Future<void> stop();

  /// 释放当前 source 占用的解码器资源（可重新 load）。
  Future<void> release();

  Future<void> seek(Duration position);
  Future<void> setVolume(double volume);

  /// 单曲循环由引擎实现（JustAudio 用原生 LoopMode.one；audioplayers 见 §8-Q2）。
  Future<void> setLoopSingle(bool loop);

  bool get isPlaying;
  Duration get position;
  Duration? get duration;

  /// 当前已加载的文件路径（null = 未加载）。
  String? get loadedPath;

  /// 播放进度（实现方保证 ~200ms 量级，不得每帧）。
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;

  /// 单曲自然播完（切歌/暂停/停止不触发）。
  Stream<void> get completionStream;

  /// 错误（加载失败 / 播放失败），由适配器统一成引擎无关类型。
  Stream<AudioEngineError> get errorStream;

  Future<void> dispose();
}
```

设计要点：

* **接口里没有队列、没有 index、没有 shuffle** —— 这是本次架构目标的核心表达。
* 与 just_audio 的差异（`stop()` 语义、`completed` 状态、`ProcessingState`）全部在 `JustAudioEngine` 内部消化，`PlayerService` 不再感知。
* `loadedPath` 让"惰性加载 / macOS 沙箱时序"（**启动阶段绝不预加载文件**）这一既有硬约束得以保留：`PlayQueue.restoreQueue()` 只恢复内存数据，任何 `load()` 都必须等到用户首次播放动作。
* **实现必须可多实例化**（构造函数无副作用、`dispose()` 干净）：为将来可能的"双实例预加载"实现留门（见附录 C）。届时只需新增一个组合式实现，`PlayerService` 与接口都不必改。
* **不提供"预加载下一首"的 API**：一旦提供，就会被实现成"把队列交给引擎"，镜像队列问题立刻回归。将来若确实需要，再加一个**带默认 no-op 的**可选方法（非破坏性变更）。

---

## 5. 分阶段计划

### Phase 0 — 准备（~0.5h）

| 步骤 | 命令 / 动作 |
|---|---|
| 1 | `git switch dev && git pull` （确认 `dev @368b05d`、工作区干净） |
| 2 | `git switch -c feature/audioplayers-engine` |
| 3 | 记录基线：`flutter analyze`（当前 0 告警）、`flutter test`（**198 通过**）、`flutter build macos --debug`（SPM，无 CocoaPods 提示） |
| 4 | 把本文档的"坑清单"（附录 B）加进分支的 checklist，避免重复踩 |

**产出**：基线记录。
**验收**：三条命令输出与本文件一致。

---

### Phase 1 — 抽接口 + JustAudioEngine 单曲适配器（0.5–1 天，**仅分支内**）

**本阶段产出的单曲化 `JustAudioEngine` 不会合进 `dev`**（在 just_audio 上单曲化会丢 gapless，见 §0.4）。它的作用只是**隔离验证**：先确认队列逻辑重构本身没坏，再换引擎。本阶段仍要求**行为零变化**。

1. 新增 `lib/core/audio/audio_engine.dart`（抽象 + `AudioEngineError` + 工厂 `createAudioEngine()`）。
2. 新增 `lib/core/audio/just_audio_engine.dart`：把现有对 `AudioPlayer` 的调用（含 `_applyAudioModes`、`effectiveIndices` 换算、`stop()` 语义转换、事件流订阅）**原样搬进来**。
3. `PlayerService` 构造函数改为接受 `AudioEngine`；`ServiceLocator` 注入 `createAudioEngine()`。
4. 删掉 `service_locator.dart` 里的 `JustAudioPlatform.instance.disposeAllPlayers(...)` —— 改为在引擎实现的 `create()` 阶段处理（JustAudioEngine 保留该逻辑，AudioplayersEngine 依赖其 6.2.0+ 的自动清理）。

> 说明：本阶段只是**搬家**——把现有对 `AudioPlayer` 的调用（含队列型调用与 `effectiveIndices` 换算）原样搬进 `JustAudioEngine`，`PlayerService` 对外行为不变，因此从本阶段起产物**已不具备 gapless**（每次切歌都要重新装载单曲）。这是分支内的临时取舍，仅用于验证后续重构。

**交付**：`flutter analyze` 0 告警、`flutter test` 198 通过、手测一次常规播放流程。
**风险**：低。唯一注意点是事件流顺序（`positionStream` 的 200ms 节流语义不能变）。

---

### Phase 2 — 队列逻辑去引擎化 + FakeEngine 单测（1–1.5 天，**分支内**）

**这是"消除两套队列"的实质步骤，与 audioplayers 无关**——但同样留在分支内（Phase 1 之后产物已无 gapless）。

1. 把 `JustAudioEngine` 中残留的队列型辅助（`_applyAudioModes`、`effectiveIndices` 换算、队列编辑 API）剥离出去，引擎实现收敛为 §4 的单曲能力（`load/play/pause/stop/release/seek/volume/loopSingle`）。
2. 把下列逻辑上移到 `PlayerService`（并删除 just_audio 遗留补丁）：
   * **索引推进**：`onCompletion` → repeat/是否末曲 → next / loop / 队尾收尾。
   * **随机排列**：Dart 侧 `List<int> _shuffleOrder`，在随机开关、`playFromList`、加歌/插队、删歌、`moveInQueue`、`pruneQueue`、每轮回绕时修补；对外保持 `effectiveQueue` / `effectiveIndex` / `logicalIndexForEffective` 语义。
   * **队尾收尾**：显式状态机（替代 `_handlingQueueEnd` + `_reconcile` + `_lastEventIndex`）。
   * **续播位置消费时机**：唯一入口，避免历史上"`initialPosition=0` 覆盖续播点"的问题复发。
3. 新增 `test/fake_audio_engine.dart` + 单测（**本阶段最大的长期价值**），覆盖：
   * next/previous/jumpTo 在**首/中/尾**三态
   * repeat off/all/one × 随机 on/off 的 6 种组合
   * 随机下增/删/移动/插队后排列正确性 + 每轮重洗
   * 队尾收尾（索引回 0、位置归零、不发自动播放）
   * 坏文件连续失败 → 自动跳转 → 连续 3 次停止
   * 续播位置消费（开关开/关、首次加载 vs 手动切歌）
   * 完成后位置不外泄 0（UI 一致性）

**交付**：`AudioEngine` 单曲化；`PlayerService` 不再有 `_rebuildSequence` / `_handlingQueueEnd` / `_reconcile`；新增 ≥25 个单测。
**验收**：`flutter analyze` 0 告警；全量测试（198 + 新增）通过；macOS 手测回归见 §6。
**风险**：中。这是行为等价性重构里最需要小心的一步，靠单测 + 手测清单兜底。
**注意**：本阶段结束时引擎仍是 just_audio，但已被降级为单曲模式 → **产物不具备 gapless**。因此同样**不合并**，继续留在分支内进入 Phase 3。

---

### Phase 3 — AudioplayersEngine 实现（1.5–2.5 天）

在同一个 `feature/audioplayers-engine` 分支内继续（不重开分支）。

1. `pubspec.yaml`：`just_audio` / `just_audio_platform_interface` 改为 `audioplayers: ^6.8.1`（**保留 just_audio 至决策通过**，两者可共存，只在 A/B 阶段同时存在）。
2. 新增 `lib/core/audio/audioplayers_engine.dart`，逐条处理附录 B 的坑：
   * `positionUpdater = TimerPositionUpdater(interval: 200ms)`
   * `ReleaseMode.stop`（**不要用默认的 `release`**）+ 单曲循环用 `ReleaseMode.loop` 并**忽略其 completion**
   * `seek` 前置守卫（未加载 → 只记 pending，不调引擎）
   * 完成瞬间位置归零屏蔽（`_completedAt`）
   * 错误三路归并（`eventStream.onError` / `setSource*` future / `play()` future）→ `errorStream`
   * `stop()` → `stop()` + 位置归零；`release()` → 释放解码器
3. `createAudioEngine()` 直接返回 `AudioplayersEngine`（不再保留运行时切换开关——对比改为两个构建产物，见 §3）。
4. **不要顺手写双实例（双 player）预加载方案** —— 见附录 C：它不是真 gapless，只是把"设置延迟"换成"交接延迟"，却引入两个解码器与一整套"哪一个是活动实例"的状态机。Phase 4 拿到实测数值后再判断必要性；若确实要做，也应在迁移完成后以**组合式实现**（`PreloadingAudioEngine implements AudioEngine`）落地，`PlayerService` 与接口都不必改。

**交付**：`PlayerService` 的队列逻辑一行不改即可跑在 audioplayers 上（引擎差异全部封在 `AudioplayersEngine` 内）。
**验收**：`flutter analyze` 0 告警；全量测试通过（引擎无关逻辑应全绿）；`flutter build macos --debug` 成功且**未生成 Podfile / 未走 CocoaPods**（SPM 支持见附录 B-10）。

---

### Phase 4 — A/B 实测与决策（0.5–1 天）

用同一份曲库、同一组操作，对**两个构建产物**跑 §6 清单：基线 = `dev` 构建（just_audio + 原生队列），实验 = 本分支构建（audioplayers + 单曲引擎）。重点记录：

| 指标 | 测量方式 | 门槛（建议） |
|---|---|---|
| 曲间空隙 | 临时拼测试素材：取同一专辑两首曲子，砍掉第一首尾部静音使其紧接第二首开头 | **已确认非门槛**，仅记录数值 |
| **尾部截断** | 挑结尾有明显鼓点/长音的曲目，与基线对比是否被吃掉 | **不得比基线差（硬性）** |
| 切歌延迟 | 数字库大文件，`next()` 到手感就绪 | ≤ ~250ms |
| 未加载时拖进度条 | 启动后不播放直接拖 | 无 30s 卡死、无异常弹窗 |
| 坏文件报错延迟 | 截断/改名的 mp3 | ≤ ~2s 出 SnackBar 并自动跳 |
| 内存/CPU | Activity Monitor 播放中观察 | 不高于基线 +10% |
| 热重启 | 按 `R` | 无幽灵播放器（不出双声） |

**交付**：一份对比结论（写入 `docs/Performance-Optimization.md` 或本文件 §9）。
**验收**：所有门槛有明确"通过/未过"记录。

---

### Phase 5 — 合并或放弃（~0.5 天）

| 结论 | 动作 |
|---|---|
| **采纳** | 合 `feature/audioplayers-engine` 进 `dev`（同一个 PR：新引擎 + 移除 `just_audio` 依赖与 `JustAudioEngine`）；更新 `Architecture.md`（补 `AudioEngine` 分层）、`README.md`、`CHANGELOG.md`、`docs/TODO.md`；同步 `/memories/repo/` |
| **放弃** | **丢弃整条分支**（`dev` 自始至终未被触碰，无需回滚）；把结论与实测数据写进本文件，避免以后重复评估 |
| **部分采纳** | 若结论是"要消除镜像队列、但不接受丢 gapless"：放弃迁移，另行评估「适配器收敛」——把 just_audio 的镜像/回退补丁集中到一个适配器类，`PlayerService` 不再直接接触引擎类型。收益是可读性/可测性，**不是**引擎可替换 |

三种结论都必须更新本文件的 §9「结论」。

---

## 6. 手测回归清单（两个引擎都要跑）

**播放基础**
- [ ] 播放 / 暂停 / 上一首 / 下一首（队列首、中、尾三态）
- [ ] 上一首在 >3s 时重播当前曲（`previous()` 既有语义）
- [ ] 从音乐库/专辑/歌手/播放列表/我的收藏点歌起播
- [ ] 播放中切换页面、切 tab（保活）、开关播放页 — 状态不丢

**队列语义**
- [ ] 队尾 repeat off 收尾：播完停、索引回 0、进度归零、**不自动播放**
- [ ] repeat one（单曲循环）：无缝衔接、不误跳下一首
- [ ] repeat all：末曲 → 首曲
- [ ] 随机 + 随机循环：每轮重洗、回绕不重复、队列视图顺序 = 实际播放顺序
- [ ] 队列视图自动定位到当前曲（`effectiveIndex` 契约）
- [ ] 播放中删当前曲 / 删其它曲 / 拖动排序 / 加到队列尾部 / 播放下一首
- [ ] 未播放（仅恢复队列）状态下做上述操作
- [ ] 随机开启时歌曲菜单「播放下一首」隐藏（业务规则需重新确认，见 §8-Q3）

**进度与持久化**
- [ ] 启动续播（开）：进度条显示续播点、歌词对齐、从头不重播
- [ ] 启动续播（关）：进度显示 0、从头播放
- [ ] **未播放时拖动进度条**（重点：audioplayers 的 seek 守卫）
- [ ] 音量滑块（拖动结束落盘）、菜单 ⌘↑/⌘↓、重启后音量为最新值
- [ ] 菜单「停止」→ 位置归零，再播放从头开始

**周边**
- [ ] 歌词：跟随高亮、切歌重载、点击行跳转、翻译开关
- [ ] macOS 媒体控制：控制中心 / Dock / 媒体键 / 锁屏信息与封面
- [ ] 关窗驻留后台继续播放；重开窗口状态正确
- [ ] 热重载 / 热重启（`R`）无幽灵播放器
- [ ] 坏文件：SnackBar + 自动跳下一首 + 连续 3 次停止
- [ ] 删除文件夹 / 快速刷新 → 队列 prune；**无实际变更时不应重启序列**（防卡顿）
- [ ] 播放中删除正在播放的文件
- [ ] 格式抽样：FLAC / ALAC(m4a) / MP3 / 中文名 / 日文名 / 高码率

---

## 7. 工作量与风险

| Phase | 内容 | 估算 | 风险 |
|---|---|---|---|
| 0 | 准备 | 0.5h | 低 |
| 1 | 接口 + JustAudioEngine | 0.5–1 天 | 低 |
| 2 | 去引擎化 + FakeEngine 单测 | 1–1.5 天 | 中 |
| 3 | AudioplayersEngine | 1.5–2.5 天 | **中高**（附录 B 的坑） |
| 4 | A/B 实测 | 0.5–1 天 | 低 |
| 5 | 合并/放弃 | 0.5 天 | 低 |
| — | **合计** | **4–6 天** | 若追加"双 player 伪 gapless"再 +1–2 天，且**不保证达标** |

**主要风险**

1. **gapless 退化**（结构性，无法在 audioplayers 单 player 模型内解决）。
2. 切歌延迟与完成瞬间的位置/状态抖动（附录 B-3/7）。
3. audioplayers 的状态机历史上有竞态修复记录（6.4 才修 darwin 内存泄漏与 dispose，6.2.0 才支持 hot restart 清理）——比 just_audio 的 darwin 实现简单，但需要重新积累信任。
4. 若真实产品目标是 iOS/Android（当前代码里已有 `PlatformMediaControls.create()` 的占位和 `audio_session` 依赖链），迁移会牵动音频会话/焦点配置（`AudioContext`）。

---

## 8. 待定问题（需实测或你拍板）

| # | 问题 | 建议 |
|---|---|---|
| Q1 | ~~gapless 是否是硬需求？~~ **已确认（2026-09-16）：非硬需求**（曲库中没有连续型专辑） | 不作为通过门槛；仍必须检查尾部截断与 padding（§0.4） |
| Q2 | 单曲循环放引擎还是应用层？ | 接口保留 `setLoopSingle`；JustAudio 用原生 `LoopMode.one`；audioplayers 若 `ReleaseMode.loop` 有可闻空隙，则退化为应用层 `completion → seek 0 → play`，并在 ADR 里记录差异 |
| Q3 | 「随机开启时隐藏『播放下一首』」这条规则 | 现在的依据是 just_audio 的随机槽位行为；Phase 2 后需按新排列语义重新定义（`song_actions.dart` 注释同步） |
| Q4 | 是否顺手把 `PlayerService` 拆分？ | 建议：`PlayerService`（对外 API 不变）+ 内部队列状态机（`lib/core/services/queue_playback.dart`），便于单测 |
| Q5 | 是否引入 Windows/Linux 支持？ | audioplayers 自带实现（Windows: Media Foundation；Linux: GStreamer，需系统开发库），属**额外收益**，但当前无 Windows 媒体控制实现，不构成本次迁移理由 |
| Q6 | 是否要做"双实例预加载"（两个 AudioPlayer 交替）？ | **现在不做** —— 不是真 gapless，只是把"设置延迟"换成"交接延迟"，代价见附录 C。Phase 4 拿到实测数值后再判断；若要做，以组合式 `PreloadingAudioEngine` 落地，接口与 `PlayerService` 都不变 |

---

## 9. 结论

> 待 Phase 4 完成后填写：采纳 / 放弃 + 实测数据 + 最终引擎与依赖清单。

---

## 附录 A：对外契约（迁移期间不得改变）

- `PlayerService`：`playFromList` / `playFromSong` / `addToQueue` / `playNext` / `removeFromQueue` / `moveInQueue` / `jumpTo` / `clearQueue` / `pruneQueue` / `play` / `pause` / `togglePlay` / `stop` / `stopPlayback` / `next` / `previous` / `seek` / `setVolume` / `adjustVolume` / `cyclePlayMode` / `toggleSingleRepeat` / `setPlayMode` / `resyncFromAudio` / `toggleFavoriteForCurrent` / `takePlaybackError`
- 通知器：`currentSongNotifier` / `playingNotifier` / `uiListenable`（**不得含 positionStream**）/ `positionStream`
- 属性：`queue` / `currentIndex` / `currentSong` / `isPlaying` / `position` / `duration` / `repeatMode` / `baseRepeatMode` / `isShuffled` / `volume` / `effectiveQueue` / `effectiveIndex` / `logicalIndexForEffective`
- `PlayQueue` 的 JSON 结构（`play_queue.json`：filePath 列表 + `currentIndex` + `repeatMode` + `isShuffled` + `positionMs` + `durationMs`）**不得变更**，否则破坏向后兼容。

## 附录 B：源码级坑清单（audioplayers 6.8.1）

| # | 坑 | 出处 / 依据 | 应对 |
|---|---|---|---|
| 1 | 无队列：`AudioPlayer` 一次只能有一个 source | 官方 getting_started | 架构按 §4 单曲接口设计 |
| 2 | darwin 用单 `AVPlayer` + `replaceCurrentItem`，**无预取、无 gapless** | `audioplayers_darwin/.../WrappedMediaPlayer.swift` | Q1 决策；否则双 player 方案 |
| 3 | `onPlayerComplete` 内部先 `_platform.stop()`（位置归零），`ReleaseMode.release` 下还 `release()` 并置 `_source = null` | `audioplayers/lib/src/audioplayer.dart` | 完成态屏蔽 `_completedAt`；用 `ReleaseMode.stop` |
| 4 | `ReleaseMode.loop` **也会**触发 `onPlayerComplete` | 同上（文档明示） | loop 模式必须忽略 completion |
| 5 | `seek()` 会 `await onSeekComplete.first.timeout(30s)`；darwin 在**无 currentItem 时直接 return 且不发该事件** → 未加载时 seek 会挂到超时 | `audioplayer.dart` + `WrappedMediaPlayer.swift` | 引擎层加守卫：未加载只记 pending |
| 6 | `onPositionChanged` 默认 `FramePositionUpdater`（**每帧一次平台调用**） | `audioplayer.dart` 构造函数 | 换 `TimerPositionUpdater(200ms)`，保住现有性能假设 |
| 7 | `setSourceUrl` 失败走 event stream 的 `onError`，**future 仍成功**；`preparationTimeout` / `seekingTimeout` 是静态 30s | darwin 插件 `catch` 分支 | 错误三路归并；必要时调小 timeout |
| 8 | `stop()` 位置归零、`release()` 释放解码器且可重载 | 官方文档 | 正好匹配 `stopPlayback()` 语义，简化现有 hack |
| 9 | macOS 分支不引用 `MediaPlayer.framework`（`MediaPlayer` 仅在 `#if os(iOS)` 分支 import） | darwin 插件源码 | 不会与我们的 `MediaControlsPlugin` 抢 Now Playing；仍建议实机确认 |
| 10 | **SPM 已支持**：`darwin/audioplayers_darwin/Package.swift`（6.3.0+） | 仓库文件 + CHANGELOG | 继续纯 SPM，**不需要恢复 CocoaPods** |
| 11 | 6.2.0 起 hot restart 自动 dispose players；`AudioPlayer.global` 的 `init` 会清掉上一个 isolate 的原生 player | CHANGELOG + darwin 插件 | 可删 `disposeAllPlayers` hack |
| 12 | iOS/macOS 的 AVPlayer **只接受带扩展名的路径** | 官方 troubleshooting | 项目按 `supportedAudioExtensions` 过滤，影响很小 |
| 13 | 新增传递依赖 `uuid` / `synchronized` / `http` / `file` | pub.dev | `Rules.md` §Dependencies：已核对维护状态/许可证（MIT）/平台支持 |

## 附录 C："双实例预加载"为什么不是真 gapless（2026-09-16 评估）

### C.1 思路

类似双缓冲：播放 A 时先把 B 的 source 设好并 prepare，A 播完立刻 `B.resume()`，两者角色互换。

### C.2 为什么它做不到 gapless

真 gapless 的前提是"下一首在**同一个音频管线内**被调度"——这正是 `AVQueuePlayer` + `actionAtItemEnd = Advance` 做的事（`just_audio` 就是靠它），而**应用层拿不到这个能力**。两个独立的 `AVPlayer` / `ExoPlayer` 是两条独立管线：

1. **交接只能靠"结束通知"驱动**：`AVPlayerItemDidPlayToEndTimeNotification` → 平台通道 → Dart → `B.resume()` → 平台通道 → B 起播。这一圈本身就是延迟。
2. **不能提前起播**：提前 = 两轨重叠（可闻的双声/梳状滤波），除非做交叉淡化（那是另一个功能，不是 gapless）。
3. **padding / encoder delay 依旧存在**：A 的尾部 padding 与 B 的头部 delay 属文件级问题，换实例解决不了（见 §2.1 的 ②）。

**结论**：双实例能把间隙从"设置延迟"（`stop → release → setSource → await prepared`）压缩到"交接延迟"（通知 + 通道往返 + 起播）——量级可能从几百 ms 降到十几~几十 ms，但**不是 0**。

### C.3 代价（为什么现在不做）

| 类别 | 具体问题 |
|---|---|
| 状态机 | 需要维护"哪个实例是活动的"；待机实例不得触发 completion、不得被误 `resume()`；索引变化时预加载失效与重建 |
| 抖动 | 连续点 next、拖动排序、随机重排、seek 到接近末尾时，预加载目标频繁变化 → 需要去抖，否则两个实例反复 `setSource`，**比不预加载更慢** |
| 资源 | 两个解码器 + 两份文件句柄/缓冲（Hi-Res FLAC 下可能几十 MB）；官方 troubleshooting 提到 iOS/macOS 存在 AVPlayer 实例上限风险 |
| 外围 | 音量 / 媒体控制 / 错误上报要覆盖两个实例；热重启幽灵播放器风险翻倍 |
| 收益 | 换来的只是几十毫秒 —— 而 **Q1 已确认这不是门槛** |

### C.4 如果将来真的要做

**放进引擎实现内部，不要污染接口**：

```dart
/// 组合式实现：内部持有两个基础引擎，对外仍然是一个单曲 AudioEngine。
class PreloadingAudioEngine implements AudioEngine { /* ... */ }
```

前提是 §4 的约束"实现必须可多实例化"被遵守。届时需要给接口再加一个**带默认 no-op 的**可选方法（例如 `Future<void> hintNext(String? path) async {}`）来告知"下一首是谁"——非破坏性变更，现有实现不受影响。

> ⚠️ 硬性约束：该方法的**默认实现必须是 no-op**；绝不能让 just_audio 实现去"把整个队列交给引擎"，否则镜像队列问题会立刻回归（这正是 §0.4 描述的互斥性）。
