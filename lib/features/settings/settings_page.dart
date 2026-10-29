import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/accent_color.dart';
import '../../core/services/album_art_cache_service.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/app_locale.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/l10n.dart';
import '../../widgets/page_toolbar.dart';
import '../shell/shell_controller.dart';
import 'about_page.dart';
import 'log_page.dart';
import 'lyrics_settings_page.dart';
import 'widgets/option_row.dart';

/// 设置页：分组卡片（音乐库 / 播放设置 / 外观 / 通用）。
class SettingsPage extends StatefulWidget {
  /// Shell 控制器（「音乐库 › 强制刷新」动作由此切到音乐库并触发）。
  final ShellController? controller;

  /// 是否为当前选中的 tab；从非激活切回激活时刷新缓存大小等快照数据。
  final bool active;

  const SettingsPage({super.key, this.controller, this.active = true});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// 续播开关（启动时从设置读取，默认开）。
  bool _resumePlayback = true;

  /// 主题模式（启动时从设置读取，默认跟随系统）。
  ThemeMode _themeMode = ThemeMode.system;

  /// 界面语言（`'system'` / `'en'` / `'zh'`，启动时从设置读取）。
  String _locale = 'system';

  /// 界面强调色（启动时从设置读取，默认石墨灰）。
  AccentColor _accent = AccentColor.graphite;

  /// 底栏播放进度填充开关（启动时从设置读取，默认开）。
  bool _nowPlayingBarFill = true;

  /// 睡眠定时「到点先播完当前曲」开关（启动时从设置读取，默认关）。
  bool _sleepTimerFinishCurrentTrack = false;

  /// 切歌时是否弹系统横幅通知（启动时从设置读取，默认开）。
  bool _showTrackChangeNotification = true;

  /// 封面缓存大小（字节）；null = 尚未加载成功。
  int? _cacheSizeBytes;

  /// 菜单（ShellController 广播）进来的页面动作，如「关于本软件」。
  StreamSubscription<ShellAction>? _actionsSub;

  @override
  void initState() {
    super.initState();
    // 设置页是 Shell 惰性保活 tab，首次选中才构建；此时 ServiceLocator 通常
    // 已就绪，但仍加守卫兜底（用户可能初始化完成前就切到设置）。
    if (ServiceLocator.isReady) {
      _resumePlayback = ServiceLocator.settings.resumePlaybackPosition;
      _themeMode = ServiceLocator.settings.themeMode;
      _locale = ServiceLocator.settings.localeName;
      _accent = ServiceLocator.settings.accentColor;
      _nowPlayingBarFill = ServiceLocator.settings.nowPlayingBarFill;
      _sleepTimerFinishCurrentTrack =
          ServiceLocator.settings.sleepTimerFinishCurrentTrack;
      _showTrackChangeNotification =
          ServiceLocator.settings.showTrackChangeNotification;
    }
    _loadCacheSize();
    // 菜单动作（如 Help › 关于本软件）：设置页是 Shell 保活 tab，订阅常驻。
    // 广播在切 tab 后的下一帧发出，此时订阅已建立（见 ShellController.request）。
    _actionsSub = widget.controller?.actions.listen(_onShellAction);
  }

  @override
  void dispose() {
    _actionsSub?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 保活切回本页时刷新封面缓存大小（此前只在 initState 读一次，之后
    // 一直显示旧值，清理过缓存也不会变）。
    if (widget.active && !oldWidget.active) {
      _loadCacheSize();
    }
  }

  Future<void> _loadCacheSize() async {
    final size = await AlbumArtCacheService().cacheSizeBytes();
    if (!mounted) return;
    setState(() => _cacheSizeBytes = size);
  }

  /// 清理未被引用的封面缓存文件（安全：仍在使用的封面不会被动）。
  Future<void> _clearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.settingsClearCoverCacheTitle),
          content: Text(l10n.settingsClearCoverCacheBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l10n.settingsClearCoverCacheAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final removed = await ServiceLocator.songRepo.cleanupOrphanCovers();
    if (!mounted) return;
    await _loadCacheSize();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settingsCoverCacheCleared(removed))),
    );
  }

  /// 字节数 → 人类可读（B/KB/MB）。
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// 主题行 leading 图标：跟随当前主题亮度 —— 深色显示月亮、浅色显示太阳。
  IconData _themeIndicatorIcon(ThemeData theme) =>
      theme.brightness == Brightness.dark ? Icons.dark_mode : Icons.light_mode;

  /// 主题模式 → 展示文案。
  String _themeModeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => context.l10n.commonFollowSystem,
    ThemeMode.light => context.l10n.themeModeLight,
    ThemeMode.dark => context.l10n.themeModeDark,
  };

  /// 主题模式 → 图标（分段按钮窄版用）。
  IconData _themeModeIcon(ThemeMode mode) => switch (mode) {
    ThemeMode.system => Icons.brightness_auto,
    ThemeMode.light => Icons.light_mode_outlined,
    ThemeMode.dark => Icons.dark_mode_outlined,
  };

  /// 切换界面语言（UI 状态 + 写盘；MaterialApp 监听 localeNotifier 重建）。
  void _setLocale(String value) {
    setState(() => _locale = normalizeAppLocaleName(value));
    // 与歌词设置页各开关同款：控件始终可点，写盘前才判断依赖是否就绪
    // （页面可独立构建于初始化之前，`ServiceLocator.settings` 此时会抛）。
    if (!ServiceLocator.isReady) return;
    ServiceLocator.settings.setLocale(value);
  }

  /// 当前语言选项的展示文案。
  String _localeLabel(AppLocalizations l10n) => switch (_locale) {
    'en' => l10n.settingsLanguageEnglish,
    'zh' => l10n.settingsLanguageSimplifiedChinese,
    _ => l10n.settingsLanguageSystem,
  };

  /// 切换续播开关（UI 状态 + 写盘）。
  void _setResumePlayback(bool value) {
    setState(() => _resumePlayback = value);
    ServiceLocator.settings.setResumePlaybackPosition(value);
  }

  /// 切换底栏播放进度填充开关（UI 状态 + 写盘 + 通知底栏即时生效）。
  void _setNowPlayingBarFill(bool value) {
    setState(() => _nowPlayingBarFill = value);
    ServiceLocator.settings.setNowPlayingBarFill(value);
  }

  /// 切换睡眠定时「先播完当前曲再停」开关（UI 状态 + 写盘）。
  ///
  /// 播放中的定时每次到点都现读设置（`SleepTimerService.waitForTrackEnd`
  /// 回调），因此改完立即生效，无需通知播放器。
  void _setSleepTimerFinishCurrentTrack(bool value) {
    setState(() => _sleepTimerFinishCurrentTrack = value);
    ServiceLocator.settings.setSleepTimerFinishCurrentTrack(value);
  }

  /// 切换切歌通知开关（UI 状态 + 写盘）。
  ///
  /// 打开时顺带申请通知授权——这是明确的用户手势，最自然的申请时机；
  /// 用户拒绝则提示并给一个直达系统设置的入口（否则开关看着是开的却不弹，
  /// 会以为功能坏了）。通知服务每次切歌都现读设置，因此改完即时生效。
  Future<void> _setShowTrackChangeNotification(bool value) async {
    setState(() => _showTrackChangeNotification = value);
    await ServiceLocator.settings.setShowTrackChangeNotification(value);
    if (!value || !ServiceLocator.isReady || !mounted) return;

    final granted = await ServiceLocator.trackNotifications.ensurePermission();
    if (granted || !mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l10n.settingsNotificationsDenied),
          action: SnackBarAction(
            label: l10n.settingsOpenSystemSettings,
            onPressed: () => unawaited(
              ServiceLocator.trackNotifications.openNotificationSettings(),
            ),
          ),
        ),
      );
  }

  /// 跟随系统圆点的兜底监听源（非 macOS / 未就绪时无系统色服务）。
  static final ValueNotifier<Color?> _noSystemColor = ValueNotifier<Color?>(
    null,
  );

  /// 切换界面强调色（UI 状态 + 写盘 → MaterialApp 即时换肤）。
  void _setAccentColor(AccentColor accent) {
    setState(() => _accent = accent);
    ServiceLocator.settings.setAccentColor(accent);
  }

  /// 底色相对亮度 → 覆盖前景色：深底用白、浅底用深黑灰（对勾可见）。
  Color _contrastOn(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  /// 44×26 紧凑开关：M3 Switch 默认 52×32，非等比缩放（视觉+命中区同步）。
  Widget _buildCompactSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const targetW = 44.0, targetH = 26.0;
    const defaultW = 52.0, defaultH = 32.0;
    return SizedBox(
      width: targetW,
      height: targetH,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(
          targetW / defaultW,
          targetH / defaultH,
          1,
        ),
        child: Switch(value: value, onChanged: onChanged),
      ),
    );
  }

  /// 音乐库 › 强制刷新：切回音乐库 tab 并触发全量重解析（与旧长按/右键一致）。
  ///
  /// 无文件夹时按钮已置灰（onTap:null），此处只负责跳转并触发。
  void _forceRescan() {
    final controller = widget.controller;
    if (controller == null || !mounted) return;
    controller.request(NavigationItem.library, action: ShellAction.forceRescan);
  }

  /// ShellController 广播的菜单动作。
  void _onShellAction(ShellAction action) {
    if (action == ShellAction.openAbout) _openAbout();
  }

  /// 打开「关于」页（「通用 › 关于」行与菜单「关于本软件」共用）。
  void _openAbout() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AboutPage()));
  }

  /// 打开「歌词显示」页（「外观 › 歌词显示」行）。
  void _openLyricsSettings() {
    if (!mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const LyricsSettingsPage()));
  }

  /// 「音乐库」分组卡片：目前为强制刷新入口。无文件夹时禁用（ListTile 置灰）。
  Widget _buildLibraryCard() {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final hasFolders =
        ServiceLocator.isReady &&
        ServiceLocator.settings.musicFolders.isNotEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        minTileHeight: OptionRow.kHeight,
        minVerticalPadding: 16,
        enabled: hasFolders,
        leading: const Icon(Icons.refresh),
        title: OptionRowText(
          title: l10n.settingsForceRescanTitle,
          subtitle: hasFolders
              ? l10n.settingsForceRescanSubtitle
              : l10n.settingsForceRescanNoFolders,
        ),
        subtitle: null,
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        onTap: hasFolders ? _forceRescan : null,
      ),
    );
  }

  Widget _buildPlaybackCard() {
    final l10n = context.l10n;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            minTileHeight: OptionRow.kHeight,
            minVerticalPadding: 16,
            leading: const Icon(Icons.replay_rounded),
            title: OptionRowText(
              title: l10n.settingsResumeTitle,
              subtitle: l10n.settingsResumeSubtitle,
            ),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _resumePlayback,
              onChanged: _setResumePlayback,
            ),
            onTap: () => _setResumePlayback(!_resumePlayback),
          ),
          ListTile(
            minTileHeight: OptionRow.kHeight,
            minVerticalPadding: 16,
            leading: const Icon(Icons.notifications_none_rounded),
            title: OptionRowText(
              title: l10n.settingsTrackNotificationTitle,
              subtitle: l10n.settingsTrackNotificationSubtitle,
            ),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _showTrackChangeNotification,
              onChanged: _setShowTrackChangeNotification,
            ),
            onTap: () => unawaited(
              _setShowTrackChangeNotification(!_showTrackChangeNotification),
            ),
          ),
          ListTile(
            minTileHeight: OptionRow.kHeight,
            minVerticalPadding: 16,
            leading: const Icon(Icons.timer_outlined),
            title: OptionRowText(
              title: l10n.settingsSleepFinishTrackTitle,
              subtitle: l10n.settingsSleepFinishTrackSubtitle,
            ),
            subtitle: null,
            trailing: _buildCompactSwitch(
              value: _sleepTimerFinishCurrentTrack,
              onChanged: _setSleepTimerFinishCurrentTrack,
            ),
            onTap: () => _setSleepTimerFinishCurrentTrack(
              !_sleepTimerFinishCurrentTrack,
            ),
          ),
        ],
      ),
    );
  }

  /// 「主题色」行：行内直排圆点（首项「跟随系统」+ 预设色板），点选即换肤。
  Widget _buildAccentRow(ThemeData theme) {
    final l10n = context.l10n;
    // 跟随系统圆点的实时预览色：仅 macOS 有 SystemAccentService，
    // 其余平台用兜底空 notifier（恒定 null，不触发重建）。
    final systemAccent = ServiceLocator.isReady
        ? ServiceLocator.systemAccent
        : null;
    final systemColorListenable =
        systemAccent?.systemAccentNotifier ?? _noSystemColor;

    const dotsGap = 6.0;
    final count = AccentColor.values.length;
    final fullMinWidth = 16.0 * count + dotsGap * (count - 1);

    return OptionRow(
      icon: Icons.palette_outlined,
      title: l10n.settingsAccentTitle,
      subtitle: l10n.settingsAccentSubtitle,
      // 色板圆点直径要按可用宽度自适应，所以直接用 LayoutBuilder 读剩余宽度。
      trailing: ValueListenableBuilder<Color?>(
        valueListenable: systemColorListenable,
        builder: (context, systemColor, _) => LayoutBuilder(
          builder: (context, constraints) {
            final available = constraints.maxWidth;
            if (available >= fullMinWidth) {
              // 宽度足够：圆点自适应填满（上限 24），右对齐。
              final size = ((available - dotsGap * (count - 1)) / count)
                  .clamp(16.0, 24.0)
                  .floorToDouble();
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _accentDots(
                  theme,
                  size: size,
                  systemColor: systemColor,
                ),
              );
            }
            // 极端窄：固定 20 圆点 + 横向滚动兜底（不溢出）。
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _accentDots(
                  theme,
                  size: 20,
                  systemColor: systemColor,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 色板圆点列表（预设=实色圆；跟随系统=实时系统色或 auto 图标）。
  List<Widget> _accentDots(
    ThemeData theme, {
    required double size,
    required Color? systemColor,
  }) => [
    for (final accent in AccentColor.values) ...[
      if (accent != AccentColor.values.first) const SizedBox(width: 6),
      _buildAccentDot(
        theme: theme,
        accent: accent,
        size: size,
        systemColor: systemColor,
      ),
    ],
  ];

  /// 单个圆点：选中=描边+对勾；跟随系统无系统色=描边+auto 图标。
  Widget _buildAccentDot({
    required ThemeData theme,
    required AccentColor accent,
    required double size,
    required Color? systemColor,
  }) {
    final scheme = theme.colorScheme;
    final isSystem = accent.followsSystem;
    final selected = _accent == accent;
    final fill = isSystem ? systemColor : accent.seed;
    final noFill = fill == null;

    final Widget child;
    if (selected) {
      child = Icon(
        Icons.check,
        size: size * 0.6,
        color: _contrastOn(fill ?? scheme.surface),
      );
    } else if (isSystem && noFill) {
      child = Icon(
        Icons.auto_awesome,
        size: size * 0.55,
        color: scheme.onSurfaceVariant,
      );
    } else {
      child = const SizedBox.shrink();
    }

    return Tooltip(
      message: accent.label(context.l10n),
      child: GestureDetector(
        onTap: () => _setAccentColor(accent),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: fill,
            border: Border.all(
              color: selected
                  ? scheme.onSurface
                  : (isSystem && noFill
                        ? scheme.outlineVariant
                        : Colors.transparent),
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  Widget _buildAppearanceCard() {
    final theme = Theme.of(context);
    final chevronColor = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              // 宽度不足以容纳文字版三按钮时，收成图标版 + tooltip。
              // 断点按整行宽度判定（旧值 550 是去掉 16+24 内边距后的内宽，
              // 等价整行 590），行内边距改由 OptionRow 统一提供。
              final compact = constraints.maxWidth < 590;
              return OptionRow(
                // 跟随当前主题亮度：深色显示月亮、浅色显示太阳。
                icon: _themeIndicatorIcon(theme),
                title: context.l10n.settingsThemeTitle,
                subtitle: context.l10n.settingsThemeSubtitle,
                // 标签长度随语言变化（中文 3 字 vs 英文 "Follow system"），
                // 不设固定上限：宽度由 OptionRow 按「文字区保底」分配，
                // 只有真的放不下时才等比缩小（旧上限 360 会把英文标签缩到 ~0.8）。
                trailing: ShrinkableTrailing(
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      for (final mode in ThemeMode.values)
                        if (compact)
                          ButtonSegment(
                            value: mode,
                            icon: Icon(_themeModeIcon(mode)),
                            tooltip: _themeModeLabel(mode),
                          )
                        else
                          ButtonSegment(
                            value: mode,
                            icon: Icon(_themeModeIcon(mode)),
                            label: Text(_themeModeLabel(mode)),
                          ),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (selection) {
                      final mode = selection.first;
                      setState(() => _themeMode = mode);
                      ServiceLocator.settings.setThemeMode(mode);
                    },
                  ),
                ),
              );
            },
          ),
          _buildAccentRow(theme),
          // 「歌词显示」二级页：字号 / 翻译 /（后续）样式与动效。
          ListTile(
            minTileHeight: OptionRow.kHeight,
            minVerticalPadding: 16,
            leading: const Icon(Icons.lyrics_outlined),
            title: OptionRowText(
              title: context.l10n.settingsLyricsTitle,
              subtitle: context.l10n.settingsLyricsSubtitle,
            ),
            subtitle: null,
            trailing: Icon(Icons.chevron_right, color: chevronColor),
            onTap: _openLyricsSettings,
          ),
          // 底栏播放进度填充开关（「外观」分组）。
          ListTile(
            minTileHeight: OptionRow.kHeight,
            // 与其它设置行一致的行高（续播/通用各行均为 16）。
            minVerticalPadding: 16,
            leading: const Icon(Icons.timeline_rounded),
            title: OptionRowText(
              title: context.l10n.settingsNowPlayingFillTitle,
              subtitle: context.l10n.settingsNowPlayingFillSubtitle,
            ),
            trailing: _buildCompactSwitch(
              value: _nowPlayingBarFill,
              onChanged: _setNowPlayingBarFill,
            ),
            onTap: () => _setNowPlayingBarFill(!_nowPlayingBarFill),
          ),
        ],
      ),
    );
  }

  /// 「语言」行：弹出菜单选择跟随系统 / English / 简体中文。
  ///
  /// ⚠️ `PopupMenuButton` 包在 `ListTile` **外层**（与歌词设置页的「行间过渡」行
  /// 同款），整行都是点击区。若只把它放进 `trailing`，就只有右侧那一小块可点，
  /// 行体是死的 —— 与其它所有设置行的手感不一致。
  Widget _buildLanguageRow(ThemeData theme) {
    final l10n = context.l10n;
    return PopupMenuButton<String>(
      initialValue: _locale,
      onSelected: _setLocale,
      itemBuilder: (menuContext) => [
        CheckedPopupMenuItem(
          value: 'system',
          checked: _locale == 'system',
          child: Text(menuContext.l10n.settingsLanguageSystem),
        ),
        CheckedPopupMenuItem(
          value: 'en',
          checked: _locale == 'en',
          child: Text(menuContext.l10n.settingsLanguageEnglish),
        ),
        CheckedPopupMenuItem(
          value: 'zh',
          checked: _locale == 'zh',
          child: Text(menuContext.l10n.settingsLanguageSimplifiedChinese),
        ),
      ],
      child: ListTile(
        minTileHeight: OptionRow.kHeight,
        minVerticalPadding: 16,
        leading: const Icon(Icons.language),
        title: OptionRowText(
          title: l10n.settingsLanguageTitle,
          subtitle: l10n.settingsLanguageSubtitle,
        ),
        subtitle: null,
        // 只是展示当前值 + 下拉箭头；点击由外层 PopupMenuButton 接管，
        // 箭头右缘因此与其它行的 chevron 落在同一条内缘上。
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _localeLabel(l10n),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralCard() {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final chevronColor = theme.colorScheme.onSurfaceVariant;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      elevation: 0,
      color: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildLanguageRow(theme),
          ListTile(
            minTileHeight: OptionRow.kHeight,
            minVerticalPadding: 16,
            leading: const Icon(Icons.receipt_long_outlined),
            title: OptionRowText(
              title: l10n.settingsLogsTitle,
              subtitle: l10n.settingsLogsSubtitle,
            ),
            subtitle: null,
            trailing: Icon(Icons.chevron_right, color: chevronColor),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const LogPage())),
          ),
          ListTile(
            minTileHeight: OptionRow.kHeight,
            minVerticalPadding: 16,
            leading: const Icon(Icons.photo_library_outlined),
            title: OptionRowText(
              title: l10n.settingsCacheTitle,
              subtitle: l10n.settingsCacheSubtitle,
            ),
            subtitle: null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _cacheSizeBytes == null
                      ? '…'
                      : _formatBytes(_cacheSizeBytes!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: _clearCache,
                  // 淡淡的描边：与页面其它细线同色（`outlineVariant`，不是 M3
                  // OutlinedButton 默认的 `outline`），让这个次要动作在行尾有
                  // 边界感，又不抢主题色；尺寸/内边距保持 TextButton 不变，
                  // 行内不会再被撑宽。
                  style: TextButton.styleFrom(
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  icon: const Icon(Icons.cleaning_services, size: 18),
                  label: Text(l10n.settingsClearCoverCacheAction),
                ),
              ],
            ),
          ),
          ListTile(
            minTileHeight: OptionRow.kHeight,
            minVerticalPadding: 16,
            leading: const Icon(Icons.info_outline),
            title: OptionRowText(
              title: l10n.settingsAboutTitle,
              subtitle: l10n.settingsAboutSubtitle(
                ServiceLocator.appVersion ?? '',
              ),
            ),
            subtitle: null,
            trailing: Icon(Icons.chevron_right, color: chevronColor),
            onTap: _openAbout,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        PageToolbar(title: l10n.settingsTitle),
        const Divider(height: 1),
        Expanded(
          // 项目约定：含 ListTile/InkWell 的滚动区必须外包透明 Material +
          // Clip.hardEdge，防止墨水波纹渗出到标题区。
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.hardEdge,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _buildSectionHeader(l10n.settingsSectionLibrary),
                _buildLibraryCard(),
                _buildSectionHeader(l10n.settingsSectionPlayback),
                _buildPlaybackCard(),
                _buildSectionHeader(l10n.settingsSectionAppearance),
                _buildAppearanceCard(),
                _buildSectionHeader(l10n.settingsSectionGeneral),
                _buildGeneralCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
