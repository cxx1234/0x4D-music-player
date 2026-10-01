import 'package:flutter/material.dart';

/// 弹出菜单（`PopupMenuButton` / `showMenu`）统一的展开动画。
///
/// ### 为什么要有这个常量
///
/// `PopupMenuThemeData` **没有** `popUpAnimationStyle` 字段，主题里设不了，
/// 只能由每个入口自己把它传给 `PopupMenuButton` / `showMenu`。
///
/// ### 为什么从默认的 `Curves.linear` 换成 ease-out
///
/// `_PopupMenuState` 把一条 0→1 的时间轴切成几段（面板整体淡入 `[0, 1/3]`、
/// 宽度 `[0, unit]`、高度生长 `[0, unit × 项数]`、每个条目再各自一个 `Interval`
/// 阶梯，`unit = 1/(项数 + 1.5)`），而曲线是**先作用在这条时间轴上**的，
/// 所以它决定"每一段值何时到达"。
///
/// 默认 `linear` 下"值 = 真实时间比例"：满项数的菜单里最后一条要等到约 267ms
/// 才出场，而面板在前 100ms 就已经淡实 —— 观感是"框先实，内容再慢慢往外蹦"。
/// 换成 ease-out 后进度整体前移（最后一条约 156ms 就出场），尾部剩下的那 1/3
/// 时长只跑最后几个百分点的值、几乎看不见，于是显得更快更利落，**而总时长仍是
/// 框架默认的 300ms**。
///
/// ⚠️ 这里只给了 `curve`，没给 `reverseCurve`：关闭仍由框架默认值决定 ——
/// `_PopupMenuRoute` 不读 `AnimationStyle.reverseDuration`（进和出永远一样长），
/// 且默认反向曲线 `Interval(0.0, 2/3)` 会把关闭的**头 1/3 时长压成完全静止**。
/// 要修掉那个停顿，在这里补 `reverseCurve: Curves.easeInCubic` 即可。
const AnimationStyle kPopupMenuAnimationStyle = AnimationStyle(
  curve: Curves.easeOutCubic,
);
