/// 全局布局配置（顶部区域 / 页面工具栏相关，按平台区分）。
///
/// 旧的全局顶栏（TopBar）已移除，改为「页面避让」方案：
/// - 左侧边栏顶部预留 [PlatformLayoutConfig.sidebarTopInset]，供 macOS 红绿灯悬浮；
/// - 右侧内容区各页使用统一高度的 [PageToolbar]（见 lib/widgets/page_toolbar.dart）。
///
/// 各平台取值见 [_macOS] / [_default]。macOS 独有红绿灯，因此
/// [PlatformLayoutConfig.sidebarTopInset] 仅 macOS 非 0；其余平台暂与 macOS
/// 取相同的工具栏高度，数值等调试 Windows 版时再按需微调。
///
/// 见 docs/UI-Rules.md。
library;

import 'package:flutter/foundation.dart';

/// 一套平台相关的顶部/工具栏布局参数。
class PlatformLayoutConfig {
  const PlatformLayoutConfig({
    required this.sidebarTopInset,
    required this.sidebarWidth,
    required this.pageToolbarHeight,
    required this.pageToolbarTopInset,
    required this.pageToolbarContentHeight,
    required this.detailTopBarHeight,
    required this.detailTopBarLeftInset,
    required this.playerTopBarTopReserve,
  });

  /// 左侧边栏顶部预留高度（红绿灯所在区域）。
  /// 仅 macOS 需要；其余平台无红绿灯，为 0。
  final double sidebarTopInset;

  /// 左侧边栏（NavigationRail）宽度：macOS 100（红绿灯组水平居中），其余 80。
  final double sidebarWidth;

  /// 右侧内容区页面标题工具栏总高
  /// （= [pageToolbarTopInset] + [pageToolbarContentHeight]）。
  final double pageToolbarHeight;

  /// 工具栏顶部填充（替代被移除的全局顶栏高度）。
  final double pageToolbarTopInset;

  /// 工具栏内容块高度：标题/计数/操作按钮在其中垂直居中。
  final double pageToolbarContentHeight;

  /// 二级详情页顶部栏（DetailTopBar）总高。
  final double detailTopBarHeight;

  /// 详情页顶部栏左侧预留：macOS 让过红绿灯组（≈73.5，取 80）；其余平台为 0。
  final double detailTopBarLeftInset;

  /// 播放页顶栏顶部的红绿灯预留区高度：macOS 45，其余平台 0。
  /// 播放页顶栏总高 = 56 控件区 + 本值（macOS 101 = 56 + 45）。
  final double playerTopBarTopReserve;
}

/// macOS：unified 工具栏，红绿灯原生居中（中心 ≈26，顶栏 52）；侧栏宽 92；
/// 工具栏 112 = 32 + 80；详情页顶栏 52，左侧让过红绿灯（95）；播放页顶部红绿灯预留 40。
const _macOS = PlatformLayoutConfig(
  sidebarTopInset: 52,
  sidebarWidth: 90,
  pageToolbarHeight: 112,
  pageToolbarTopInset: 32,
  pageToolbarContentHeight: 80,
  detailTopBarHeight: 52,
  detailTopBarLeftInset: 95,
  playerTopBarTopReserve: 40,
);

/// Windows 及其他平台：无红绿灯，左栏顶部不留白（0），详情页左侧不留白（0）；
/// 播放页顶部无预留（0）；工具栏数值暂与 macOS 一致，调试 Windows 版时再微调。
const _default = PlatformLayoutConfig(
  sidebarTopInset: 0,
  sidebarWidth: 90,
  pageToolbarHeight: 62,
  pageToolbarTopInset: 32,
  pageToolbarContentHeight: 80,
  detailTopBarHeight: 52,
  detailTopBarLeftInset: 0,
  playerTopBarTopReserve: 0,
);

/// 当前平台使用的布局配置。
PlatformLayoutConfig get layoutConfig => switch (defaultTargetPlatform) {
  TargetPlatform.macOS => _macOS,
  _ => _default,
};
