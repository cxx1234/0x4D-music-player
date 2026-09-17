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
- i18n 多语言支持 → 已纳入本文件 §3 Phase 1（只搭基建，暂不迁移现有字符串）。

## 其他已登记待办

- ⛔ **just_audio 0.10 迁移收尾**（2026-08-11 → 2026-08-13 完成；**2026-09-17 随引擎替换作废**——just_audio 已被 `audioplayers` 取代，见 `docs/AudioEngine-Migration.md`）：`player_service.dart` 已改用 0.10 新 playlist API（`setAudioSources` / `addAudioSources` / `removeAudioSourceAt` / `insertAudioSources` / `moveAudioSource`），4 处 `ConcatenatingAudioSource` 弃用警告清零；`_rebuildSequence` 兜底逻辑保留。`dart analyze` 干净、`flutter test` 27/27 通过。
- ✅ **歌词全屏页红绿灯避让**（2026-08-19 关闭）：`LyricsPage` 已随 2026-08-15 播放页 6a 重构删除（歌词并入播放页右栏/窄版 tab），用户已重新设计界面方案，不再存在独立全屏歌词页的避让问题。
- **日志查看页接入导航**（2026-08-11）：`LogPage` / `LogDetailPage` 已实现接入，设置页。
- ✅ **播放页 10px 溢出**（2026-08-19 关闭）：原 `_LeftPanel` 已随 2026-08-17 播放页重构（SongInfoCard + PlayerBar）删除；现信息区包在 `SingleChildScrollView` + `Expanded` 内、底部播放条固定，结构上不再有该溢出，实际运行未复现。
- ✅ **清理 `measureTrafficLights()` 诊断打印**（2026-08-19 关闭）：用户决定改用 macOS 11+ 特定窗口栏实现效果，原红绿灯测量方案被取代。

## 3. macOS 菜单栏 & Windows 适配 — 后续阶段（2026-08-30 登记）

> **macOS 菜单栏已完成**（2026-09-17：原生菜单 + Dart 桥接，Phase 2/3 关闭）。
> 以下 Phase 1/4/5 为后续阶段，实施时再展开。

### Phase 1 — Flutter i18n 基建（只搭基建，不迁移）
- `pubspec.yaml` 加 `flutter_localizations`(sdk) + `intl`
- 新建 `l10n.yaml` + `lib/l10n/app_en.arb` + `app_zh.arb`（先放最少字符串，如 appTitle）
- `flutter gen-l10n` 生成 `AppLocalizations`
- `app.dart` MaterialApp 接 `localizationsDelegates`/`supportedLocales`；`title` 改用 AppLocalizations
- 现有页面硬编码中文**本轮不迁移**（后续分阶段）
- 验证：`flutter analyze` 0 告警；gen-l10n 正常

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
