import 'package:flutter/material.dart';

import '../core/constants/motion.dart';
import 'menu_morph_route.dart';
import 'morph_menu.dart';

/// 鼠标右键（次级点击）菜单的公共入口。
///
/// **样式按控件形态分两种，不按右键这个手势分 —— 目标是「右键弹出来的东西和
/// 左键点那个按钮弹出来的长得一样」：**
/// - [showRowMenu]：行状条目（列表行 / 队列行 / 我的收藏条）→ **标准弹出菜单**
///   （`showMenu`），锚在行尾的菜单槽位 —— 与 `SongTile` 三点按钮同一位置、
///   同一套动画和行样式（见 [rowMenuSlot]）。
/// - [showCardMenu]：网格卡片（专辑 / 播放列表）→ 容器变换菜单，与卡片自己的
///   三点 / 长按同一套（见 `docs/UI-Rules.md` §11）。
///
/// 行内本来就有三点按钮的行（歌曲行）两个都不走：那种行右键等价于点三点，直接调
/// `PopupMenuButtonState.showButtonMenu()`，位置与动画天然一致。
///
/// 通用约束：锚点必须现取（列表/网格滚动过之后控件位置就变了），所以调用方传的
/// 是**组件自己的 context**，由 [overlayRectOf] 换算到 overlay 坐标。

/// `SongTile` 行尾三点按钮的命中区尺寸：`IconButton` 默认 padding 8 + iconSize 24。
///
/// 右键菜单锚在同样尺寸的槽位上，才能和「点三点」出现在同一个位置。
const double kRowMenuSlotSize = 40;

/// `ListTile` 的默认水平内边距；行尾三点按钮就贴在它的内缘。
const double _kListTileHorizontalPadding = 16;

/// 网格卡片菜单的进场 / 退场时长，比 `MenuMorphRoute` 的默认（320 / 220）短一档。
///
/// 「卡片翻开成选项」这个叙事不需要那么久：320ms 放在网格里读起来是「慢」
/// （行状条目的标准弹出菜单一开始就给人这种感觉，见 `docs/UI-Rules.md` §12）。
/// 只作用于 [showCardMenu]；睡眠定时那个入口仍用 `MenuMorphRoute` 的默认值。
const Duration _kCardMenuOpenDuration = Duration(milliseconds: 240);
const Duration _kCardMenuCloseDuration = Duration(milliseconds: 180);

/// 列表行尾的菜单锚点：与行内三点按钮同尺寸、同位置（行右内缘往左一个按钮）。
///
/// [rowRect] 是**行自己**的矩形（`ListTile` 的 RenderBox，已含列表自身的
/// padding）；`ListTile` 内部还会再留 16 水平内边距，所以按钮右缘在
/// `rowRect.right - 16`。
///
/// 行状但非 `ListTile` 的条目（如「我的收藏」那条宽卡）也用这个：视觉上就是
/// 「贴在条目右端、垂直居中」，和歌曲行的三点完全对得上。
Rect rowMenuSlot(Rect rowRect) => Rect.fromLTWH(
  rowRect.right - _kListTileHorizontalPadding - kRowMenuSlotSize,
  rowRect.center.dy - kRowMenuSlotSize / 2,
  kRowMenuSlotSize,
  kRowMenuSlotSize,
);

/// overlay 的 RenderBox；拿不到时 null（调用方静默不弹菜单）。
RenderBox? _overlayBoxOf(BuildContext context) {
  final object = Overlay.maybeOf(context)?.context.findRenderObject();
  return object is RenderBox ? object : null;
}

/// 取 [context] 对应控件在 **overlay 坐标**里的矩形（菜单就锚在 overlay 里）。
///
/// ⚠️ 必须传**组件自己的** context。`SliverChildBuilderDelegate.itemBuilder` 的
/// context 会解析到 `RenderSliverGrid` / `RenderSliverList` 这类 RenderSliver，
/// 拿不到行/卡片的矩形（那时返回 null，调用方静默不弹菜单）。
Rect? overlayRectOf(BuildContext context) {
  final object = context.findRenderObject();
  if (object is! RenderBox || !object.hasSize) return null;
  final overlayObject = _overlayBoxOf(context);
  if (overlayObject == null) return null;
  return overlayObject.globalToLocal(object.localToGlobal(Offset.zero)) &
      object.size;
}

/// 封面卡片的右键菜单：从卡片底边向上长出来，面板与卡片同宽。
///
/// 与播放列表卡片的三点按钮 / 长按菜单完全同一套观感 —— 起点是贴在卡片底边的
/// 一条窄边（不是整张卡片）：卡片与面板高度接近，直接用整张卡片当起点的话整段
/// 动画只剩底边往上收，看着像「卡片塌下来」。
Future<T?> showCardMenu<T>({
  required BuildContext context,
  required Rect cardRect,
  required List<MorphMenuEntry<T>> entries,
}) {
  const stripHeight = 12.0;
  final anchorStrip = Rect.fromLTWH(
    cardRect.left,
    cardRect.bottom - stripHeight,
    cardRect.width,
    stripHeight,
  );
  return Navigator.of(context).push<T>(
    MenuMorphRoute<T>(
      anchorRect: anchorStrip,
      grow: MenuMorphGrow.up,
      duration: _kCardMenuOpenDuration,
      reverseDuration: _kCardMenuCloseDuration,
      panelSize: Size(
        MorphMenuPanel.widthForAnchor(context, cardRect.width, entries),
        MorphMenuPanel.heightFor(entries),
      ),
      // 起点取卡片的圆角与底色：看着就是这张卡片自己翻成了选项。
      anchorShape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      panelShape: const RoundedRectangleBorder(borderRadius: kMorphMenuRadius),
      anchorColor: Theme.of(context).colorScheme.surfaceContainerLow,
      builder: (context, close) =>
          MorphMenuPanel(entries: entries, onSelected: close),
    ),
  );
}

/// 行状条目的右键菜单：**与 `SongTile` 三点按钮同位置、同一套样式与动画**。
///
/// 用标准弹出菜单（`showMenu`）而不是容器变换：这里没有「按钮那个小矩形要长成
/// 面板」的叙事，条目也不在窗口最底部（§11 那条定位缺陷主要影响贴底的锚点），
/// 标准菜单进场更干脆。锚点算得和 `PopupMenuButton` 内部一模一样，所以同一个
/// 位置用右键与用鼠标点三点，弹出来的东西完全一致。
///
/// [entries] 就是 `PopupMenuEntry`（与 `SongTile.menuBuilder` 同一类型），所以
/// 行状条目的菜单可以直接复用 `song_actions.dart` 那套菜单项工厂。
Future<T?> showRowMenu<T>({
  required BuildContext context,
  required Rect rowRect,
  required List<PopupMenuEntry<T>> entries,
}) {
  final overlayObject = _overlayBoxOf(context);
  if (overlayObject == null) return Future<T?>.value(null);

  return showMenu<T>(
    context: context,
    popUpAnimationStyle: kPopupMenuAnimationStyle,
    // 与 PopupMenuButton 内部同一算法：把按钮矩形换算成相对 overlay 的边距。
    position: RelativeRect.fromRect(
      rowMenuSlot(rowRect),
      Offset.zero & overlayObject.size,
    ),
    items: entries,
  );
}
