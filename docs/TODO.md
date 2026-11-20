# TODO / 计划

本文件登记待办事项与后续优化计划。按日期登记，完成后标注 ✅。

## 1. macOS 音乐文件夹访问权限优化（2026-08-15 登记，后期处理）

### 背景
- app 是 macOS 沙盒应用，音乐文件夹默认在 `~/Music/Music`（macOS 音乐 App 资料库位置）。
- 该路径受系统 **「媒体与 Apple Music」**（Media Library TCC）权限保护；而 app 通过 `FilePicker`(NSOpenPanel) + security-scoped bookmark 访问，走的是「文件与文件夹」授权，**不会触发** Media Library 权限请求。
- 现象：`resolveBookmark` / `startAccessingSecurityScopedResource` / `Directory.exists` 都成功，但 `dir.list` 仍报 `Operation not permitted, errno=1`。
- 现状：已通过 **系统设置 → 隐私与安全性 → 媒体与 Apple Music → 手动添加 `0x4D.app`** 解决（持久授权，重启/重扫均正常，日志 `Scan done: ... found 432 audio file(s), 0 error(s)`）。

### 待办（后期二选一或组合）
1. **方案 A：app 主动请求 Media Library 权限**（对应「2」）
   - 加 entitlement `com.apple.security.personal-information.media-library`；
   - 原生层触发一次 Media Library 访问（如 `MPMediaLibrary`），让系统弹「允许访问媒体资料库吗」；
   - 目的：降低对「用户手动去系统设置添加」的依赖。
   - 评估：当前仅读文件，收益有限，需权衡后再做。
2. **方案 B：把音乐文件夹移出 `~/Music`**
   - 如移到 `~/Documents/Music`，走「文件与文件夹」的 FilePicker 授权，用户「添加文件夹」时即自动授权，无需进系统设置；
   - 代价：需迁移现有 527 个文件（`~/Music/Music`）。
3. **方案 C（最轻量）**：✅ 2026-09-17 完成，README 已加「macOS permissions」小节（手动添加到「媒体与 Apple Music」）。

## 2. 发布前待办（非性能）

- ✅ **macOS 菜单栏与键盘快捷键**（2026-09-17 关闭）：原生菜单（App / 编辑 / 查看 / 播放 / 窗口 / 帮助）+ Dart 桥接已完成；通道改名为 `com.jerryc.txvziwm/menu`。
- ✅ **依赖可复现**（2026-09-17 关闭）：`audio_metadata_reader` 由分支名改为固定 commit `4a6f245413d8f0f11f4a8e7613a9ae9ee0681eae`。
- ✅ **设置页「清理缓存」**（2026-09-17 关闭）：由占位改为真实删除未被引用的封面（复用 `SongRepository.cleanupOrphanCovers()`），并刷新缓存大小。
- ⛔ **`setTopBarHeight` 桥接**（2026-09-17 移除）：Dart 调用 + Swift no-op handler 均已删除，红绿灯由 unified 工具栏原生定位。
- **Impeller 开关（R5）决策**：`macos/Runner/Info.plist` 中 `FLTEnableImpeller=false` 为全局关闭（Intel 与 Apple Silicon 均生效）。**保留现状**——Intel macOS 上 Impeller 存在闪烁/阴影栅格问题（见 `docs/Performance-Optimization.md` §7）；待上游修复后再按机型评估是否重新启用。
- **Windows 窗口最小尺寸（`WM_GETMINMAXINFO`）** → 见 §3 Phase 4，仍未做（需 Windows 环境验证，不阻塞 macOS 发布）。
- **Windows SMTC（系统媒体控制）** → 见 §3 Phase 5，仍未做（不阻塞 macOS 发布）。
- **字体资源**：`assets/fonts/BoutiqueBitmap9x9_Circle_Dot.ttf`（5.8MB）无任何引用且未在 `pubspec.yaml` 声明，建议删除（或在 `fonts:` 中正式声明后使用，否则会白占仓库体积；未打包进 app，不影响发布包大小）。
- ✅ **i18n 多语言支持**（2026-10-24 关闭）：基建与全部界面文案迁移已完成（English / 简体中文），约定见 `docs/I18n.md`；仅 macOS 原生菜单仍跟随系统语言，见 §3 第 4 项。

## 其他已登记待办

- ⛔ **just_audio 0.10 迁移收尾**（2026-08-11 → 2026-08-13 完成；**2026-09-17 随引擎替换作废**——just_audio 已被 `audioplayers` 取代，见 `docs/AudioEngine-Migration.md`）：`player_service.dart` 已改用 0.10 新 playlist API（`setAudioSources` / `addAudioSources` / `removeAudioSourceAt` / `insertAudioSources` / `moveAudioSource`），4 处 `ConcatenatingAudioSource` 弃用警告清零；`_rebuildSequence` 兜底逻辑保留。`dart analyze` 干净、`flutter test` 27/27 通过。
- ✅ **歌词全屏页红绿灯避让**（2026-08-19 关闭）：`LyricsPage` 已随 2026-08-15 播放页 6a 重构删除（歌词并入播放页右栏/窄版 tab），用户已重新设计界面方案，不再存在独立全屏歌词页的避让问题。
- **日志查看页接入导航**（2026-08-11）：`LogPage` / `LogDetailPage` 已实现接入，设置页。
- ✅ **播放页 10px 溢出**（2026-08-19 关闭）：原 `_LeftPanel` 已随 2026-08-17 播放页重构（SongInfoCard + PlayerBar）删除；现信息区包在 `SingleChildScrollView` + `Expanded` 内、底部播放条固定，结构上不再有该溢出，实际运行未复现。
- ✅ **清理 `measureTrafficLights()` 诊断打印**（2026-08-19 关闭）：用户决定改用 macOS 11+ 特定窗口栏实现效果，原红绿灯测量方案被取代。

## 3. macOS 菜单栏 & Windows 适配 — 后续阶段（2026-08-30 登记）

> **macOS 菜单栏已完成**（2026-09-17：原生菜单 + Dart 桥接，Phase 2/3 关闭）。
> **i18n 基建已完成**（2026-10-24，Phase 1 关闭）。以下 Phase 4/5 为后续阶段，
> 实施时再展开。

### Phase 1 — Flutter i18n 基建（只搭基建，不迁移）✅ 2026-10-24
- ✅ `pubspec.yaml` 加 `flutter_localizations`(sdk) + `intl`，并启用 `generate: true`
- ✅ 新建 `l10n.yaml` + `lib/l10n/app_en.arb` + `app_zh.arb`（当前只有语言设置文案）
- ✅ `flutter gen-l10n` 生成 `AppLocalizations`，生成物随仓库提交
- ✅ `app.dart` MaterialApp 接 `localizationsDelegates`/`supportedLocales`/`locale`；
  应用名 `0x4D` 是品牌名，保持硬编码
- ✅ 语言设置（跟随系统 / English / 简体中文）持久化到 `settings.json`；
  非中文系统回退英文；歌词翻译副行改跟随应用语言
- ✅ 现有页面硬编码中文**本轮不迁移**（后续分阶段，约定见 `docs/I18n.md`）
- ✅ 验证：`flutter analyze` 除 `tool/` 历史 info 外无新增；`flutter test` 390 通过

### i18n 后续迁移
1. 分批迁移 `features/` / `widgets/` 的硬编码中文（每批更新两份 ARB 与测试）
   - ✅ 公共层 + Shell（2026-10-24）：启动错误页、导航、迷你播放条、播放控制、
     搜索/空状态、歌曲行/信息卡
   - ✅ 设置域（2026-10-24）：设置页、歌词设置、关于、日志；设置相关 core 枚举
     的标签改由 `lib/l10n/enum_labels.dart` 提供
   - ✅ 音乐库 / 专辑 / 歌手（2026-10-24）：含 `SongSortOrder` 标签、扫描结果
     复数与英文逗号分隔
   - ✅ 播放列表（2026-10-24）：页面 / 详情 / 收藏 / 导入导出 / 选择弹层 /
     歌曲菜单
   - ✅ 播放页 / 队列 / 歌词 / 睡眠定时（2026-10-24）
2. 去掉 core 枚举自带的 `label`/`description`，改 `lib/l10n` 映射
   - ✅ 主题色 / 歌词字号 / 效果强度 / 切句动画 / 对齐 / 距离模糊（2026-10-24）
   - ✅ `SongSortOrder`（随音乐库批次，2026-10-24）
3. ✅ 服务层消息语义化（2026-10-24）：播放错误 → `PlaybackFailure`、睡眠定时
   提示 → `SleepTimerNotice`；HUD 注入 `AppLocalizations`
4. macOS 原生菜单跟随应用内语言（Dart 推 `setLocale` + Swift 按语言 bundle 重建菜单）
5. ✅ 硬编码文案护栏测试（2026-10-24）：`lib/` 除 `lib/l10n/` 外出现中文字面量即失败

### Phase 4 — Windows 最小集
- `windows/runner/win32_window.cpp` `MessageHandler` 处理 `WM_GETMINMAXINFO` → `ptMinTrackSize = (640,520)×DPI`（对齐 macOS `contentMinSize`）
- `windows/runner/Runner.rc` 显示名已是 `0x4D`（2026-09-17 核验，无需改动）
- `lib/core/constants/layout.dart` `_default` 核验 `pageToolbarHeight=62` vs `topInset32+content80=112` 不一致（预存问题，Windows 调试时按需调整）
- 验证：Windows 机器 `flutter build windows` + 运行，窗口最小 640×520

### Phase 5 — Windows SMTC（系统媒体控制，对标 macOS 媒体键/Now Playing）
- 新建 `lib/core/audio/windows_media_controls.dart`（镜像 `MacOsMediaControls` 通道协议，`MediaControlService` 零改动）
- 新建 `windows/runner/media_controls_plugin.{cpp,h}`（C++/WinRT `SystemMediaTransportControls` + `ButtonPressed` → EventChannel）
- `windows/runner/CMakeLists.txt` 加源文件 + `flutter_window.cpp` 手动注册插件（非 pub 包，不进 generated registrant）
- `lib/core/audio/platform_media_controls.dart` `create()` 加 Windows 分支
- 验证：Windows 机器构建运行，任务栏媒体悬浮/系统媒体面板显示 Now Playing、媒体键控制播放
- ⚠️ 风险：C++/WinRT 若 SDK 不含 `winrt` 头，改走 `cppwinrt` NuGet 或 `audio_service`

## 4. 播放列表 M3U 导入的跨设备匹配（2026-11-03 登记，✅ 2026-11-20 完成）

### 背景（当初的问题）
- 导出只写 `#EXTINF:<秒>,<标题>` + 绝对路径，文件里没有库内 id / hash。
- 导入把 `#` 行全丢掉，逐条走 `getSongByFilePath` 做 **file_path 字符串精确等值**，
  路径不同即全部 unmatched（跨设备根目录、大小写、symlink、`~`、`file://`、
  Windows 反斜杠）。
- 同一首歌换容器（m4a / mp3 ↔ flac）时路径、扩展名、`file_size`、`bitrate`
  全都不同，只有元数据与时长还能对上 —— 路径类匹配必然失效。

### 已交付
- `lib/core/utils/m3u.dart`：新增 `M3uEntry`（path / durationSeconds / label /
  artist / album）；导出 `#EXTINF:<秒>,<歌手> - <标题>` 与 `#EXTART` / `#EXTALB`；
  解析保留这些行（不再一律丢弃）；`resolveM3uPath` 支持 `~` 与 `file://`。
- `lib/core/utils/m3u_match.dart`：分级匹配，每级只在候选唯一（或确认是同一首歌
  的多份拷贝）时命中，否则落到下一级，最后计入未匹配：
  1. 路径精确相等
  2. 归一化路径（macOS / Windows 大小写不敏感）
  3. 父目录名 + 去扩展名文件名（只换容器仍能命中）
  4. 元数据指纹：标签归一化后比较（小写、折叠空白、去常见标点）；有 `#EXTART`
     时按 歌手 + 标题；时长先 ±1s 再 ±3s 收窄；专辑用于去歧义
  5. 标签只有标题时按标题匹配，**要求候选唯一**，否则判未匹配（不猜）
- 多份拷贝的确定性取舍：无损（flac / alac / wav / aiff / ape / wv）优先，其次 id 最小。
- 导入改为一次 `getAvailableSongs()` 建内存索引：替代逐条 SELECT，并保证
  `is_available = 0`（文件已删）的行不会被导入。
- 文件内重复条目去重后单独计数，不再虚报导入数、也不计入「未匹配」。
- 导入弹层新增「N 首按元数据匹配（路径不同）」
  （`playlistImportMatchedByMetadata`，中英两份 ARB）。

### 未做（需产品决策，未列入本轮）
- 导出增加「相对路径」选项：默认仍是绝对路径。
- 每条多写一行自定义指纹注释（如 `#0X4D-FP:...`）做精确回环。`#EXTART` /
  `#EXTALB` 已覆盖跨设备场景，暂不需要。
- 若将来加 iOS target，无损优先会选到不可播格式，需按平台能力表调整。
- 导出仍只写绝对路径：`fileSize` 类匹配需要磁盘 stat，跨设备拿不到，已放弃该层。

### 验证
- `flutter analyze`：无新增（仅既有 material 弃用 info 与 `tool/` 的 avoid_print）
- `flutter test`：498 通过；新增用例见 `test/m3u_test.dart`（导出/解析/路径）
  与 `test/m3u_match_test.dart`（分级优先级、唯一性、跨容器、多拷贝取舍、重复条目）

## 5. 歌曲信息面板 — Phase 2（2026-11-19 登记，未实现）

本轮只读、只用库内已有字段（见 `docs/UI-Rules.md` §18）。以下都要等
`audio_metadata_reader` fork 或 schema 变更：

- **位深 / 声道 / 编码**：`AudioMetadata` 不暴露。fork 内部已解析 FLAC 的位深
  （STREAMINFO 的 5 bit 字段）与 ALAC magic cookie `offset 9`，但被丢弃；`.m4a`
  的 `alac` / `mp4a` sample entry 类型也没有暴露 → 现在只能显示 `M4A`。
  改 fork 后需升 pin + **强制重扫**（已有行的 `bitrate` / `sampleRate` 来自旧解析器）。
- **音轨总数 / 碟总数 / 语言**：parser 有 `trackTotal` / `totalDisc` / `language`，
  `songs` 表没存。加列要 schema v7，存量行需重扫回填；面板目前只显示 `3`，
  回填后可在格式化层拼成 `3 / 12`。
- **标签编辑**：fork 有 writer（ID3v2 / FLAC / MP4 / APE），但需要处理重扫、
  封面缓存失效、`FolderWatcherService` 回声与失败回滚。
- **在 Finder 中显示**：沙盒下 `Process.run('open')` 不可用，需原生
  `NSWorkspace.shared.activateFileViewerSelecting` 通道。
- **独立窗口**：Flutter 仍无官方桌面多窗口 API；迁移约束已写进
  `docs/UI-Rules.md` §18（入口只传 songId、DTO 可序列化、View 不碰服务）。
