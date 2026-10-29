# 0x4D 音乐播放器

[English](README.md) · **简体中文**

一个用 **Flutter** 写的本地音乐播放器。

<p align="center">
  <img src="assets/icon/0x4D_logo_rounded.png" alt="应用图标" width="120">
  <br/>
  <img src="screenshots/0x4D_V0_2.png" alt="0x4D 音乐播放器" width="720">
  <br/><br/>
  <img src="screenshots/0x4D_V0_2_Now_Playing.png" alt="正在播放与同步歌词" width="720">
  <br/>
  <sub>正在播放 —— 逐字填充与切句动画的同步歌词</sub>
</p>

## 为什么叫 0x4D？

`0x4D` 是十六进制的 77，也就是字母 **M** 的 ASCII 码。名字就是把「Music」交给底层工具去拼写的
样子；图标也是同一个思路：字母用 9×9 点阵字体排出，一个像素一个圆点，中间穿过一个扁平化的八分音符。

## 功能

- **本地音乐库** —— 选一个文件夹，扫描并解析内嵌元数据（标题、艺术家、专辑艺术家、专辑、音轨、碟号、时长、年份、风格、比特率、采样率、封面）。文件变动由 watcher 自动同步；移除文件夹时会一并清理失去引用的专辑与艺术家。
- **专辑与艺术家** —— 网格浏览，各自有详情页（专辑页按碟号分组），支持「播放全部」。
- **播放列表** —— 新建 / 重命名 / 删除、从音乐库添加歌曲、拖动排序、导入导出 **M3U8**，另有内置的**我的收藏**视图。
- **页内搜索** —— 在音乐库、专辑、艺术家、播放列表里实时过滤并显示匹配数量。
- **播放队列** —— 下一首播放、拖动排序、循环模式与随机播放；队列内容、随机/循环状态和播放进度都会跨重启保留。
- **Hi-Res 音频** —— 通过 `audioplayers` 播放，支持 FLAC 等无损格式。
- **歌词** —— 正在播放页支持 LRC/QRC/YRC 同步歌词，自动探测音频同目录的歌词文件，或读取内嵌标签。双语行（如中日）会拆成两条时间轴，播放进度按每一帧驱动高亮。
- **歌词显示** —— 独立的 **设置 › 外观 › 歌词显示** 页，播放页工具栏也可进入。宽窗口时左侧是循环播放的实时预览，右侧是控件：字号与翻译、逐字填充与 Word Pop、切句动画、行波浪、距离模糊、前奏/间奏倒计时点。预览与播放页共用同一份 preset，所见即所得。
- **系统媒体控制**（macOS）—— 锁屏 / 媒体键控制（播放、暂停、上一首、下一首、拖动进度），带「正在播放」元数据与封面；Dock 菜单、关闭后恢复窗口。
- **界面多语言** —— 英文与简体中文，在**设置 › 通用 › 语言**切换（跟随系统 / English / 简体中文），无需重启。
- **智能排序** —— 基于拼音与日文假名的排序键，让音乐库按自然顺序排列。
- **封面缓存** —— 封面只提取一次并缓存，浏览更流畅。
- **音量与收藏** —— 持久化音量控制，播放条上可直接切换收藏。
- **日志与错误处理** —— 分级文件日志加内置查看页、启动错误页，以及播放出错时的优雅降级（自动跳过并限制重试次数）。

### 计划中

- 无缝播放（Gapless）
- DSD 支持
- Windows / Linux 支持（可能？）

`android/`、`ios/`、`web/` 三个目录已在 0.4.x 移除：它们从来都只是模板脚手架，
没有针对性的实现。若日后需要，用 `flutter create --platforms=<name> .` 按需重建。

## 开始使用

### 环境要求

- Flutter SDK（Dart `^3.12`）—— 见 [flutter.dev](https://flutter.dev)
- 目前以 macOS 为主要目标平台（系统媒体控制集成最完整）。Windows / Linux 在计划中；
  **iOS、Android 与 Web 不在目标范围内** —— 播放器依赖桌面文件系统访问（通过
  security-scoped bookmark 扫描任意文件夹）与桌面布局。

### 构建与运行

```bash
flutter pub get
flutter run -d macos
```

> 改到 `macos/` 下的任何东西（Swift / 原生代码）都需要原生重新编译：退出 App，删掉
> `build/macos`，再重新运行 —— 热重载和热重启都不会重新编译 Swift。**不要执行
> `flutter clean`**：本项目里它会卡死在经 Swift Package Manager 构建的 SQLite native assets 上。

### 多语言

界面文案位于 `lib/l10n/app_en.arb`（模板）与 `lib/l10n/app_zh.arb`。改动任意一个文件后需要重新生成
Dart 类：

```bash
flutter gen-l10n
```

应用内语言可在 **设置 › 通用 › 语言** 切换（跟随系统 / English / 简体中文），选择持久化在
`settings.json` 中。生成出来的 `app_localizations*.dart` 会一并提交。约定与已知限制见
[docs/I18n.md](docs/I18n.md) —— 其中一条是 macOS 原生菜单仍跟随系统语言。

### macOS 权限

位于 `~/Music` 下的音乐文件夹受 **「媒体与 Apple Music」** 隐私项保护。`NSOpenPanel` +
security-scoped bookmark 只授予*文件与文件夹*权限，所以首次扫描仍会报 `Operation not permitted`
（errno 1）。每台机器设置一次即可：

1. 打开 **系统设置 → 隐私与安全性 → 媒体与 Apple Music**
2. 用 `+` 添加 `0x4D.app`，保持勾选
3. 重新扫描 —— 音乐库正常载入

## 项目结构

按功能组织 —— 共享基础设施在 `core/`，业务功能在 `features/`，可复用控件在 `widgets/`。

```
lib/
├── app/          # 应用配置、路由、主题
├── core/         # 音频、数据库、服务、工具、常量
├── features/     # library、album、artist、playlist、player、settings、shell
├── models/       # 应用模型
└── widgets/      # 可复用 UI 组件
```

完整架构见 [docs/Architecture.md](docs/Architecture.md)，开发约定见 [docs/Rules.md](docs/Rules.md)。

## 技术栈

- **Flutter / Dart**
- **drift** —— 本地音乐库的 SQLite ORM
- **audioplayers** —— 音频播放（单曲；队列逻辑在应用内）
- **audio_metadata_reader** —— 元数据与内嵌封面解析（纯 Dart；使用 [cxx1234 fork](https://github.com/cxx1234/audio_metadata_reader)，固定在 commit `4a6f245` 以获得 `albumArtist` 与内嵌歌词支持）
- **flutter_lyric** —— LRC/QRC/YRC 歌词渲染，含逐字特效、切句动画与倒计时点
- **file_picker / watcher** —— 文件夹选择与音乐库变动监听
- **lpinyin** —— 拼音排序键

## 测试

```bash
flutter test
```

## 致谢

- **应用图标** —— `0x4D` 字样使用 [BoutiqueBitmap9x9 Circle Dot](https://fontspeech.blogspot.com/)
  （精品點陣體 9×9 圓形版，字言字型 / fancy type foundry）排布，图像在
  [Krita](https://krita.org/) 中完成。字体文件保留在 `assets/fonts/` 作为设计源文件，不打包进应用。
  该字体为免费软件：无论是否修改、无论商用与否，均可无限制使用、复制与分发；衍生作品须沿用同一授权，
  且 `BoutiqueBitmap` 字体名称仍为保留名称。

## 许可证

[MIT](LICENSE) © 2026 Jerry C
