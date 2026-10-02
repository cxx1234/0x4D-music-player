import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 容器变换菜单（`MenuMorphRoute`）的**公共面板**：行样式与尺寸约定只此一份。
///
/// 睡眠定时的入口与播放列表卡片共用它。抽出来的原因很实际：`MenuMorphRoute`
/// 的终点矩形必须在**打开之前**算出来（不能像弹层菜单那样先布局再定位），所以
/// 面板宽高得事先算准；两边各写一份自绘行，迟早会走样（之前就因为"写死宽度 +
/// 裸 `Row`"溢出过一次，见 `docs/Pitfalls.md`）。
///
/// 用法：
/// ```dart
/// final entries = [MorphMenuEntry('播放', 'play'), ...];
/// Navigator.of(context).push(MenuMorphRoute<String>(
///   anchorRect: anchorRect,
///   panelSize: Size(
///     MorphMenuPanel.widthFor(context, entries),
///     MorphMenuPanel.heightFor(entries),
///   ),
///   builder: (context, close) =>
///       MorphMenuPanel(entries: entries, onSelected: close),
/// ));
/// ```

/// 一行的高度（固定，不随内容变）。
const double kMorphMenuRowHeight = 48;

/// 分隔线高度。
const double kMorphMenuDividerHeight = 8;

/// 面板上下内边距。
const double kMorphMenuPaddingV = 8;

/// 条目左右内边距（高亮边缘 → 文字）。
const double kMorphMenuPaddingX = 20;

/// 勾选框宽度、以及它到文字的间距。
const double kMorphMenuCheckWidth = 16;
const double kMorphMenuCheckGap = 8;

/// 面板宽度的上下限：下限免得窄得难看，上限取 M3 菜单的 280 附近。
const double kMorphMenuMinWidth = 200;
const double kMorphMenuMaxWidth = 320;

/// 面板圆角，与全局 `PopupMenuThemeData` 的观感保持一致。
const BorderRadius kMorphMenuRadius = BorderRadius.all(Radius.circular(12));

/// 菜单里的一行：文案 + 回传值。
///
/// 两类，构造时就定死（不用另传标志位，也漏不了）：
/// - [MorphMenuEntry]：普通行，文字从内边距开始。
/// - [MorphMenuEntry.checkable]：可勾选行，左边预留勾选位（勾选框 + 间距）。
///
/// 勾选位是**按行**留的，不是整面板留：睡眠定时菜单里「15 分钟」这类普通行与
/// 「播完当前曲目」这类可勾选行分组排列，组间本来就有分隔线，所以参差的左边界
/// 读起来是「组内缩进」；而且普通行的缩进不再随「当前有没有勾选」左右漂移。
@immutable
class MorphMenuEntry<T> {
  /// 普通行：不参与勾选，左边不留位。
  const MorphMenuEntry(this.label, this.value)
    : checkable = false,
      checked = false;

  /// 可勾选行：[checked] 决定这一行画不画对勾。
  const MorphMenuEntry.checkable(this.label, this.value, {this.checked = false})
    : checkable = true;

  final String label;
  final T value;

  /// 是否可勾选（决定这一行左边留不留勾选位）。
  final bool checkable;

  /// 当前是否勾选；[checkable] 为 false 时无意义。
  final bool checked;
}

/// 容器变换菜单的面板本体。配合 [heightFor] / [widthFor] / [widthForAnchor]
/// 算 `panelSize`。
class MorphMenuPanel<T> extends StatelessWidget {
  const MorphMenuPanel({
    super.key,
    required this.entries,
    required this.onSelected,
    this.dividerAfter = const <int>{},
  });

  final List<MorphMenuEntry<T>> entries;

  /// 点中某一行：把该行的值交给调用方（通常是 `MenuMorphRoute` 的 `close`）。
  final ValueChanged<T> onSelected;

  /// 在这些下标之后插一条分隔线。
  final Set<int> dividerAfter;

  /// 面板高度 = 行数 × 行高 + 分隔线数 × 分隔线高 + 上下内边距。
  static double heightFor<T>(
    List<MorphMenuEntry<T>> entries, {
    Set<int> dividerAfter = const <int>{},
  }) {
    final dividers = dividerAfter
        .where((index) => index >= 0 && index < entries.length)
        .length;
    return entries.length * kMorphMenuRowHeight +
        dividers * kMorphMenuDividerHeight +
        2 * kMorphMenuPaddingV;
  }

  /// 面板宽度 = 最宽一行的**实测**宽度 + 勾选框 + 两侧内边距，再夹进上下限。
  ///
  /// 适合锚点很小、宽度只能由内容决定的场景（如播放条上的睡眠定时按钮）。
  /// 带上 `textScaler`：系统放大字号时面板跟着变宽，而不是把文字挤省略。
  static double widthFor<T>(
    BuildContext context,
    List<MorphMenuEntry<T>> entries,
  ) => _contentWidth(
    context,
    entries,
  ).clamp(kMorphMenuMinWidth, kMorphMenuMaxWidth);

  /// 面板宽度 = **锚点的宽度**（`anchorWidth`，即触发控件自己的宽度）。
  ///
  /// 宽度由布局决定的锚点（如播放列表卡片的网格单元）用这个：面板与卡片严丝合
  /// 缝，看着就是那张卡片本身翻成了选项，不会比它窄一截或宽一截。
  ///
  /// 下限是实测内容宽度 —— 卡片窄到放不下最长一行时宁可略宽于锚点，也不要让
  /// 行里出现省略号；上限仍是 [kMorphMenuMaxWidth]。这里**不**套
  /// [kMorphMenuMinWidth]：宽度是锚点说了算，那个下限只管「没人给宽度」的情况。
  static double widthForAnchor<T>(
    BuildContext context,
    double anchorWidth,
    List<MorphMenuEntry<T>> entries,
  ) {
    final lower = math.min(_contentWidth(context, entries), kMorphMenuMaxWidth);
    return anchorWidth.clamp(lower, kMorphMenuMaxWidth);
  }

  /// 最宽一行所需的宽度（**含**两侧内边距，**未**夹上下限）。
  ///
  /// 可勾选那组每行都要多留一个勾选位，所以两组分别量、取大 —— 只按「最宽一行」
  /// 算，会在「勾选行文案更长」的菜单里把文字挤成省略号。
  static double _contentWidth<T>(
    BuildContext context,
    List<MorphMenuEntry<T>> entries,
  ) {
    final style = Theme.of(context).textTheme.bodyMedium;
    final direction = Directionality.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    var widestPlain = 0.0;
    var widestCheckable = 0.0;
    for (final entry in entries) {
      final painter = TextPainter(
        text: TextSpan(text: entry.label, style: style),
        textDirection: direction,
        textScaler: scaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      if (entry.checkable) {
        widestCheckable = math.max(widestCheckable, width);
      } else {
        widestPlain = math.max(widestPlain, width);
      }
    }
    final widest = math.max(
      widestPlain,
      widestCheckable + kMorphMenuCheckWidth + kMorphMenuCheckGap,
    );
    return widest + kMorphMenuPaddingX * 2;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      // 面板被屏幕高度钳制时（矮窗口）靠这里滚动消化。
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: kMorphMenuPaddingV),
          for (var i = 0; i < entries.length; i++) ...[
            _row(context, entries[i]),
            if (dividerAfter.contains(i))
              const Divider(height: kMorphMenuDividerHeight),
          ],
          const SizedBox(height: kMorphMenuPaddingV),
        ],
      ),
    );
  }

  /// 一行菜单项。
  ///
  /// 只有 [MorphMenuEntry.checkable] 的行才预留勾选位（勾选框用透明图标占位，
  /// 避免选中与否让行内文字左右跳动）；普通行从内边距直接开始。
  ///
  /// 文字给 `ellipsis` 兜底：宽度虽然实测自这张表，极端字号 / 字体回退下也不该
  /// 出现溢出条纹。
  Widget _row(BuildContext context, MorphMenuEntry<T> entry) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onSelected(entry.value),
      child: SizedBox(
        height: kMorphMenuRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kMorphMenuPaddingX),
          child: Row(
            children: [
              if (entry.checkable) ...[
                Icon(
                  Icons.check,
                  size: kMorphMenuCheckWidth,
                  color: entry.checked
                      ? theme.colorScheme.primary
                      : Colors.transparent,
                ),
                const SizedBox(width: kMorphMenuCheckGap),
              ],
              Expanded(
                child: Text(
                  entry.label,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
