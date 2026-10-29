import 'package:flutter/material.dart';

/// 设置行副标题样式：比 `bodySmall` 再小一档、偏灰（与 `SongTile` 副标题一致）。
TextStyle optionRowSubtitleStyle(ThemeData theme) => theme.textTheme.bodySmall!
    .copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant);

/// 设置行的「标题 + 副标题」文本块（两行整体垂直居中）。
///
/// [OptionRow] 内部用它；`ListTile` 行也把 `title` 传成它，保证两种行型
/// 的排版完全一致（字号 / 行距 / 省略号行为）。
class OptionRowText extends StatelessWidget {
  final String title;
  final String subtitle;

  const OptionRowText({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: optionRowSubtitleStyle(theme),
        ),
      ],
    );
  }
}

/// 右侧控件带宽度上限并允许等比缩小。
///
/// 用于分段按钮：标签长度随界面语言变化（中文 2 字 vs 英文一个单词）。
/// ⚠️ 默认不设上限（`maxWidth: double.infinity`）——宽度由 [OptionRow] 的
/// 「文字区保底」规则分配：只有文字区要跌破 [OptionRow.kMinTextWidth] 时
/// 才会真的缩小。硬写一个偏小的上限会让英文标签平白缩一号（2026-10-26 的
/// 「英文胶囊按钮文字偏小」就是这么来的：上限 360 < 英文固有宽度）。
class ShrinkableTrailing extends StatelessWidget {
  final Widget child;

  /// 控件宽度上限；实际宽度 = min(固有宽度, 上限, 行内分给右槽的宽度)。
  final double maxWidth;

  const ShrinkableTrailing({
    super.key,
    required this.child,
    this.maxWidth = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: child,
      ),
    );
  }
}

/// 设置页的「leading 图标 + 标题/副标题 + 右侧控件」三段式行。
///
/// 为什么不直接用 `ListTile`：主题模式 / 歌词各项的右侧是分段按钮、主题色是
/// 横向圆点色板，两者都需要「占满剩余宽度 + 按需等比缩小」，而
/// `ListTile.trailing` 只按内容固有宽度摆放，塞不下弹性控件。
///
/// 为什么不各自手拼 `Row`：手拼会丢掉 `ListTile` 的默认行为，同一个地方已经
/// 连踩三次，本组件把那三条固化下来：
///
/// 1. 内边距 [kPadding] = `start: 16, end: 24` —— M3 `ListTile` 的默认值是
///    **非对称**的（`_LisTileDefaultsM3`），自拼行写成 `horizontal: 16` 会让
///    右缘比所有 ListTile 行凸出 8px；
/// 2. leading 图标自动 `onSurfaceVariant` —— 自拼 `Row` 里的裸 `Icon` 拿不到
///    ListTile 注入的 `IconTheme`，会退回 M2 遗留的固定纯黑/纯白；
/// 3. 行高 [kHeight] = 72 —— 与列表行（`SongTile.kRowHeight`）一致，
///    避免 ListTile 自然高度 71 与自拼 `SizedBox(72)` 混用差 1px。
///
/// 标题 / 副标题走 [OptionRowText]，与 ListTile 行同款。
class OptionRow extends StatelessWidget {
  /// 行高：与列表行（`SongTile.kRowHeight`）一致。
  static const double kHeight = 72;

  /// 左右内边距：与 M3 `ListTile` 默认值一致（左 16、右 24）。
  static const EdgeInsetsDirectional kPadding = EdgeInsetsDirectional.only(
    start: 16,
    end: 24,
  );

  /// 文字区保底宽度：再窄就只能显示成「主…」，不如让右槽继续等比缩小。
  static const double kMinTextWidth = 160;

  /// leading 图标 + 两侧固定间距占掉的宽度（24 + 16 + 8）。
  static const double _kChromeWidth = 48;

  final IconData icon;
  final String title;
  final String subtitle;

  /// 右侧控件：右对齐，**优先拿自己的固有宽度**，剩下的留给文字区。
  ///
  /// - 需要「放不下时等比缩小」→ 套一层 [ShrinkableTrailing]（分段按钮）；
  /// - 需要按可用宽度自适应（如色板圆点大小）→ 直接用 `LayoutBuilder`
  ///   读 `constraints.maxWidth`（拿到的是「分给右槽的宽度」）。
  ///
  /// 两者的可用宽度都是 `行内宽度 - 48 - [kMinTextWidth]`，因此超宽控件
  /// 不会把标题挤没。
  final Widget trailing;

  const OptionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: kHeight,
      child: Padding(
        padding: kPadding,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // 右槽优先：Row 会把非 flex 子级按固有宽度排，文字区（Expanded）
            // 吃剩下的宽度并用 ellipsis 兜底。这里只给右槽设一条上限，
            // 保证文字区不被挤到 [kMinTextWidth] 以下。
            //
            // ⚠️ 别把右槽改成 `Flexible`/`Expanded`：那是按「剩余宽度的份额」
            // 平分，英文标签比中文宽，会在宽窗口下也被缩一号（曾用 1:1 平分
            // + 360 上限，英文胶囊按钮文字只有 ~11px）。
            final maxTrailing =
                constraints.maxWidth - _kChromeWidth - kMinTextWidth;
            return Row(
              children: [
                Icon(icon, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 16),
                Expanded(
                  child: OptionRowText(title: title, subtitle: subtitle),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxTrailing > 0 ? maxTrailing : 0,
                  ),
                  child: trailing,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
