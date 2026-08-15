# TODO / 计划

本文件登记待办事项与后续优化计划。按日期登记，完成后标注 ✅。

## macOS 音乐文件夹访问权限优化（2026-08-15 登记，后期处理）

### 背景
- app 是 macOS 沙盒应用，音乐文件夹默认在 `~/Music/Music`（macOS 音乐 App 资料库位置）。
- 该路径受系统 **「媒体与 Apple Music」**（Media Library TCC）权限保护；而 app 通过 `FilePicker`(NSOpenPanel) + security-scoped bookmark 访问，走的是「文件与文件夹」授权，**不会触发** Media Library 权限请求。
- 现象：`resolveBookmark` / `startAccessingSecurityScopedResource` / `Directory.exists` 都成功，但 `dir.list` 仍报 `Operation not permitted, errno=1`。
- 现状：已通过 **系统设置 → 隐私与安全性 → 媒体与 Apple Music → 手动添加 `flutter_music.app`** 解决（持久授权，重启/重扫均正常，日志 `Scan done: ... found 432 audio file(s), 0 error(s)`）。

### 待办（后期二选一或组合）
1. **方案 A：app 主动请求 Media Library 权限**（对应「2」）
   - 加 entitlement `com.apple.security.personal-information.media-library`；
   - 原生层触发一次 Media Library 访问（如 `MPMediaLibrary`），让系统弹「允许访问媒体资料库吗」；
   - 目的：降低对「用户手动去系统设置添加」的依赖。
   - 评估：当前仅读文件，收益有限，需权衡后再做。
2. **方案 B：把音乐文件夹移出 `~/Music`**
   - 如移到 `~/Documents/Music`，走「文件与文件夹」的 FilePicker 授权，用户「添加文件夹」时即自动授权，无需进系统设置；
   - 代价：需迁移现有 527 个文件（`~/Music/Music`）。
3. **方案 C（最轻量）**：README / 文档补充一句「新环境需到系统设置 → 隐私与安全性 → 媒体与 Apple Music 添加本 App」。

## 其他已登记待办

- **just_audio 0.10 迁移收尾**（2026-08-11）：`player_service.dart` 仍有 4 处 `ConcatenatingAudioSource` 弃用警告，改用 0.10 新 playlist API；`_rebuildSequence` 兜底逻辑保留。
- **歌词全屏页红绿灯避让**（2026-08-04/05）：`LyricsPage` 的 M3 AppBar≈56 会与 macOS 红绿灯重叠，窄窗歌词展示方案待讨论。
- **日志查看页接入导航**（2026-08-11）：`LogPage` / `LogDetailPage` 已实现未接入，设置页 TODO。
- **播放页左栏 10px 溢出**（2026-08-10）：`player_page.dart` 顶部区域变矮后 `_LeftPanel` 有 10px 溢出，待修。
- **清理 `measureTrafficLights()` 诊断打印**（2026-08-10）：macOS 红绿灯测量诊断输出待删除。
