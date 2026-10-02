// 弹出菜单动画对比 demo（开发用入口，不属于 app 的 main）。
//
// 运行：
//   flutter run -d macos -t test/demo/menu_demo.dart
//
// 每个入口弹出的菜单**内容一致**（3 个预设 + 分隔线 + 播完当前曲目 + 分隔线 +
// 取消定时），只有实现方式/动画不同，便于横向对比：
//
//   1. PopupMenuButton   M2 基线（PopupMenuRoute）：300ms + Curves.linear，
//                        面板先淡实、条目逐条淡入
//   2. MenuAnchor        M3 官方菜单：进 500ms / 出 150ms（不对称），高度生长 +
//                        条目逐条淡入
//   3. DropdownButton    M2 下拉：整块淡入 → 容器整体撑开 → 其余条目逐条淡入（300ms）
//   4. DropdownMenu      M3 下拉（带输入框），内部走 MenuAnchor
//   5. 自定义 PopupRoute  整体缩放淡入，**进出时长/曲线可分别设**
//   6. 容器变换          直接调用 app 里的 `MenuMorphRoute`（位置 + 尺寸 + 圆角 +
//                        底色都从按钮插值过去）——睡眠定时菜单就是它
//   7. 原地展开          AnimatedSize + AnimatedSwitcher（不脱离布局，会挤动邻居）
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:txvziwm/widgets/menu_morph_route.dart';

void main() {
  runApp(const MenuDemoApp());
}

// ─── 菜单内容（所有实现共用同一份尺寸约定）─────────────────────────────

const double _kRowHeight = 44;
const double _kMenuWidth = 240;
const double _kMenuPadV = 8;

/// 行数：3 个预设 + 「播完当前曲目」 + 「取消定时」（写死，`const` 里不能用 `.length`）。
const int _kRowCount = 5;

/// 面板总高 = 行高 × 行数 + 两条分隔线 + 上下内边距。
const double _kMenuHeight = _kRowCount * _kRowHeight + 2 * 8 + 2 * _kMenuPadV;

const List<String> _kPresets = ['5 分钟', '15 分钟', '30 分钟'];
const String _kEndOfTrack = '播完当前曲目';
const String _kEndOfQueue = '播完当前播放列表';
const String _kCancel = '取消定时（4:59）';

/// app 里睡眠定时的预设分钟数（macOS 原生菜单里另列一份）。
///
/// 这里故意保留 7 档 —— app 内已经减到 5 档（面板高度），demo 留长一点当“长菜单”
/// 样本，用来对比各条曲线的观感。
const List<int> _kSleepPresetMinutes = [5, 10, 15, 30, 45, 60, 90];

/// 菜单面板的圆角（闭合态按钮用胶囊 18）。
const BorderRadius _kPanelRadius = BorderRadius.all(Radius.circular(12));
const BorderRadius _kPillRadius = BorderRadius.all(Radius.circular(18));

class MenuDemoApp extends StatelessWidget {
  const MenuDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '弹出菜单动画对比',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const _DemoPage(),
    );
  }
}

class _DemoPage extends StatefulWidget {
  const _DemoPage();

  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  /// 选中反馈（用 State 自己的 context：即使在路由 pop 之后调用也安全）。
  void _pick(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('选择：$value'),
          duration: const Duration(milliseconds: 900),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('弹出菜单动画对比')),
      bottomNavigationBar: _BottomBarLab(onPick: _pick),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          const _SectionTitle('四种内置实现'),
          _DemoTile(
            title: 'PopupMenuButton（框架默认）',
            note:
                'M2 基线 · PopupMenuRoute\n'
                '300ms + Curves.linear，进出同长：面板先淡实（前 1/3），条目逐条淡入',
            trigger: _popupDemo(onPick: _pick),
          ),
          _DemoTile(
            title: 'MenuAnchor',
            note: 'M3 官方菜单（现在睡眠定时用的就是这个）\n进 500ms / 出 150ms；高度自上而下生长 + 条目逐条淡入',
            trigger: Builder(
              builder: (context) => MenuAnchor(
                // ⚠️ 默认 animated: false 是"瞬开瞬合"，必须显式打开。
                animated: true,
                consumeOutsideTap: true,
                style: const MenuStyle(
                  alignment: AlignmentDirectional.topStart,
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(borderRadius: _kPanelRadius),
                  ),
                  padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  minimumSize: WidgetStatePropertyAll<Size>(
                    Size(_kMenuWidth, 0),
                  ),
                ),
                crossAxisUnconstrained: false,
                menuChildren: [
                  for (final preset in _kPresets)
                    MenuItemButton(
                      onPressed: () => _pick(preset),
                      child: Text(preset),
                    ),
                  MenuItemButton(
                    onPressed: () => _pick(_kEndOfTrack),
                    leadingIcon: Icon(
                      Icons.check,
                      size: 16,
                      color: scheme.primary,
                    ),
                    child: const Text(_kEndOfTrack),
                  ),
                  MenuItemButton(
                    onPressed: () => _pick(_kCancel),
                    child: const Text(_kCancel),
                  ),
                ],
                builder: (context, controller, child) => _PillButton(
                  label: '打开',
                  icon: Icons.timer_outlined,
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ),
          ),
          _DemoTile(
            title: 'DropdownButton',
            note: 'M2 下拉\n整块淡入 → 容器整体撑开 → 其余条目逐条淡入（300ms）；菜单默认与按钮等宽',
            trigger: DropdownButton<String>(
              value: null,
              hint: const Text('打开'),
              isDense: true,
              menuWidth: _kMenuWidth,
              borderRadius: _kPanelRadius,
              items: <DropdownMenuItem<String>>[
                for (final preset in _kPresets)
                  DropdownMenuItem<String>(value: preset, child: Text(preset)),
                // ⚠️ DropdownButton 每项固定 48 高，没有分隔线概念，这里不分隔。
                const DropdownMenuItem<String>(
                  value: _kEndOfTrack,
                  child: Text(_kEndOfTrack),
                ),
                const DropdownMenuItem<String>(
                  value: _kCancel,
                  child: Text(_kCancel),
                ),
              ],
              onChanged: (value) => value == null ? null : _pick(value),
            ),
          ),
          _DemoTile(
            title: 'DropdownMenu',
            note: 'M3 下拉（带输入框，可过滤）\n外观是输入框；动画内部走 MenuAnchor，同样是逐条淡入',
            trigger: DropdownMenu<String>(
              width: _kMenuWidth,
              hintText: '打开',
              menuHeight: 320,
              dropdownMenuEntries: <DropdownMenuEntry<String>>[
                for (final preset in _kPresets)
                  DropdownMenuEntry<String>(value: preset, label: preset),
                const DropdownMenuEntry<String>(
                  value: _kEndOfTrack,
                  label: _kEndOfTrack,
                ),
                const DropdownMenuEntry<String>(
                  value: _kCancel,
                  label: _kCancel,
                ),
              ],
              onSelected: (value) => value == null ? null : _pick(value),
            ),
          ),
          const _SectionTitle('PopupMenuButton：几组曲线/时长实例'),
          _DemoTile(
            title: '140ms + easeOutCubic',
            note:
                '2026-09-19 曾用过、后来被回退的那套\n'
                '整条时间轴一起压缩：面板淡入、生长、逐条淡入都被挤进 140ms',
            trigger: _popupDemo(
              onPick: _pick,
              style: const AnimationStyle(
                duration: Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
              ),
            ),
          ),
          _DemoTile(
            title: '240ms + 前段极快',
            note:
                'Cubic(0.05, 0.95, 0.1, 1)：动画值前 1/3 就冲到 0.9\n'
                '逐条阶梯仍在，但被压到真实时间的前 ~80ms，看着像“一起出来”',
            trigger: _popupDemo(
              onPick: _pick,
              style: const AnimationStyle(
                duration: Duration(milliseconds: 240),
                curve: Cubic(0.05, 0.95, 0.1, 1),
              ),
            ),
          ),
          _DemoTile(
            title: '只改反向曲线',
            note:
                '时长/正向全是框架默认，只把 reverseCurve 换成 easeInCubic\n'
                '对比默认的 Interval(0→2/3)：后者会让关闭的**头 1/3 时长完全静止**',
            trigger: _popupDemo(
              onPick: _pick,
              style: const AnimationStyle(reverseCurve: Curves.easeInCubic),
            ),
          ),
          _DemoTile(
            title: '禁用动画',
            note:
                'AnimationStyle.noAnimation\n'
                '瞬开瞬合；排查“别扭感”到底是动画还是定位时很好用',
            trigger: _popupDemo(
              onPick: _pick,
              style: AnimationStyle.noAnimation,
            ),
          ),
          const _SectionTitle('PopupMenuButton：现场调参'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _PopupMenuTuning(onPick: _pick),
          ),
          const _SectionTitle('自定义（可以精确控制）'),
          _DemoTile(
            title: '自定义 PopupRoute（整体缩放淡入）',
            note:
                '面板与内容**同一个曲线**：整块淡入 + 整体缩放，没有逐条阶梯\n'
                '进 180ms / 出 140ms（PopupMenuButton 做不到分开设）',
            trigger: Builder(
              builder: (context) => _PillButton(
                label: '打开',
                icon: Icons.zoom_out_map,
                onPressed: () => _showAnchoredMenu(context, _pick),
              ),
            ),
          ),
          _DemoTile(
            title: '容器变换（按钮长大成菜单）',
            note:
                'Material Motion 的 container transform\n'
                '位置 + 尺寸（RectTween）+ 圆角（ShapeBorderTween）连续插值，内容在面板里淡入淡出',
            trigger: Builder(
              builder: (context) => _PillButton(
                label: '打开',
                icon: Icons.open_in_full,
                onPressed: () => _showContainerTransform(context, _pick),
              ),
            ),
          ),
          _DemoTile(
            title: '原地展开（AnimatedSize）',
            note:
                '按钮和菜单是同一个 widget，只是尺寸在变\n'
                '最省事，但**会占布局空间**——下面这块预留了高度，所以不会挤动别人',
            trigger: const SizedBox.shrink(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _InlineExpandDemo(onPick: _pick),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── 1~4 的入口按钮外观（纯视觉，尺寸与 app 里的睡眠定时按钮一致）──────────────

class _PillLabel extends StatelessWidget {
  const _PillLabel({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: _kPillRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
          ],
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: _kPillRadius,
      child: _PillLabel(label: label, icon: icon),
    );
  }
}

// ─── 页面骨架 ──────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _DemoTile extends StatelessWidget {
  const _DemoTile({
    required this.title,
    required this.note,
    required this.trigger,
  });

  final String title;
  final String note;
  final Widget trigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              trigger,
            ],
          ),
        ),
      ),
    );
  }
}

// ─── 菜单内容（自定义实现共用）────────────────────────────────────

/// 自定义实现的菜单内容（普通 widget，不用 `PopupMenuEntry`）。
///
/// 5 行，尺寸严格等于 [_kMenuWidth] × [_kMenuHeight]，方便容器变换算终点 rect。
Widget _menuBody(BuildContext context, {required ValueChanged<String> onPick}) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;

  Widget row(String label, {bool checked = false}) {
    return InkWell(
      onTap: () => onPick(label),
      child: SizedBox(
        height: _kRowHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              if (checked) ...[
                Icon(Icons.check, size: 16, color: scheme.primary),
                const SizedBox(width: 8),
              ],
              Text(label, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  return SizedBox(
    width: _kMenuWidth,
    height: _kMenuHeight,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: _kMenuPadV),
        for (final preset in _kPresets) row(preset),
        const Divider(height: 8),
        row(_kEndOfTrack, checked: true),
        const Divider(height: 8),
        row(_kCancel),
        const SizedBox(height: _kMenuPadV),
      ],
    ),
  );
}

/// 菜单面板外壳（圆角/底色/阴影与全局 `PopupMenuThemeData` 一致）。
Widget _menuPanel(BuildContext context, Widget content) {
  return Material(
    color: Theme.of(context).colorScheme.surfaceContainer,
    elevation: 3,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(borderRadius: _kPanelRadius),
    child: content,
  );
}

// ─── 5. 自定义 PopupRoute：整体缩放淡入 ───────────────────────────

Future<void> _showAnchoredMenu(
  BuildContext context,
  ValueChanged<String> onPick,
) {
  final box = context.findRenderObject() as RenderBox?;
  final anchor = box == null
      ? Rect.zero
      : box.localToGlobal(Offset.zero) & box.size;
  return Navigator.of(context).push(
    _AnchoredMenuRoute(
      anchor: anchor,
      builder: (routeContext) => _menuPanel(
        routeContext,
        _menuBody(
          routeContext,
          onPick: (value) {
            Navigator.of(routeContext).pop();
            onPick(value);
          },
        ),
      ),
    ),
  );
}

class _AnchoredMenuRoute extends PopupRoute<void> {
  _AnchoredMenuRoute({required this.anchor, required this.builder});

  final Rect anchor;
  final WidgetBuilder builder;

  CurvedAnimation? _curved;

  // 只在创建时套一次曲线，`buildTransitions` 里直接用（别在里面 new，
  // `CurvedAnimation` 会给父级加监听，每帧新建而不 dispose 会持续泄漏）。
  @override
  Animation<double> createAnimation() {
    return _curved ??= CurvedAnimation(
      parent: super.createAnimation(),
      // ⚠️ 默认 reverseCurve 会把关闭的前 1/3 时长压成"完全静止"，
      // 这里给一条正常的反向曲线。
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  /// 进出时长可以不一样 —— 这是 `PopupMenuButton` 给不了的。
  @override
  Duration get transitionDuration => const Duration(milliseconds: 180);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 140);

  @override
  bool get barrierDismissible => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  void dispose() {
    _curved?.dispose();
    super.dispose();
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => builder(context);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 定位放在这里：`buildPage` 的结果是菜单本体，用 `CustomSingleChildLayout`
    // 把它摆到锚点下方，再对**菜单本体**做淡入 + 缩放（缩放原点 = 锚点那一角）。
    return CustomSingleChildLayout(
      delegate: _BelowAnchorLayout(anchor),
      child: FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
    );
  }
}

/// 把菜单摆到锚点下方、左对齐；贴边时收回屏幕内。
class _BelowAnchorLayout extends SingleChildLayoutDelegate {
  const _BelowAnchorLayout(this.anchor);

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(constraints.biggest);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = math.max(8.0, size.width - childSize.width - 8);
    final maxY = math.max(8.0, size.height - childSize.height - 8);
    final x = anchor.left.clamp(8.0, maxX).toDouble();
    final y = (anchor.bottom + 4).clamp(8.0, maxY).toDouble();
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_BelowAnchorLayout oldDelegate) =>
      oldDelegate.anchor != anchor;
}

// ─── 6. 容器变换：按钮长大成菜单（直接用 app 里的 MenuMorphRoute）──────

Future<void> _showContainerTransform(
  BuildContext context,
  ValueChanged<String> onPick,
) {
  final box = context.findRenderObject() as RenderBox?;
  final overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlayBox == null) return Future<void>.value();
  // 锚点换算到 overlay 坐标；**终点矩形由 MenuMorphRoute 自己按屏幕空间算**
  // （往哪边长、要不要夹进屏幕都是它的 `_MorphGeometry` 决定的），所以这个
  // 入口贴着窗口边缘也不会再长到屏幕外面去。
  final anchor =
      overlayBox.globalToLocal(box.localToGlobal(Offset.zero)) & box.size;
  return Navigator.of(context)
      .push<String>(
        MenuMorphRoute<String>(
          anchorRect: anchor,
          panelSize: const Size(_kMenuWidth, _kMenuHeight),
          builder: (routeContext, close) =>
              _menuBody(routeContext, onPick: (value) => close(value)),
        ),
      )
      .then((value) {
        if (value != null) onPick(value);
      });
}

// ─── 7. 原地展开：AnimatedSize + AnimatedSwitcher ────────────────

class _InlineExpandDemo extends StatefulWidget {
  const _InlineExpandDemo({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  State<_InlineExpandDemo> createState() => _InlineExpandDemoState();
}

class _InlineExpandDemoState extends State<_InlineExpandDemo> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 预留展开后的高度：不预留的话下面所有内容都会被顶下去（原地展开的固有代价）。
      height: _kMenuHeight + 8,
      child: Align(
        alignment: Alignment.topLeft,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          reverseDuration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainer,
            elevation: 3,
            clipBehavior: Clip.antiAlias,
            // ⚠️ 圆角是“瞬间”切换的（`AnimatedSize` 只动尺寸），
            // 要连续插值就得像上面容器变换那样用 ShapeBorderTween。
            shape: RoundedRectangleBorder(
              borderRadius: _open ? _kPanelRadius : _kPillRadius,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              child: _open
                  ? KeyedSubtree(
                      key: const ValueKey('open'),
                      child: _menuBody(
                        context,
                        onPick: (value) {
                          setState(() => _open = false);
                          widget.onPick(value);
                        },
                      ),
                    )
                  : _PillButton(
                      key: const ValueKey('closed'),
                      label: '打开',
                      icon: Icons.unfold_more,
                      onPressed: () => setState(() => _open = true),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── PopupMenuButton 调参实验室 ──────────────────────────────

/// 与其它实现内容一致的 5 项菜单（分隔线在 `PopupMenuButton` 里是可用的）。
List<PopupMenuEntry<String>> _popupMenuEntries() {
  return <PopupMenuEntry<String>>[
    for (final preset in _kPresets)
      PopupMenuItem<String>(value: preset, child: Text(preset)),
    const PopupMenuDivider(),
    CheckedPopupMenuItem<String>(
      value: _kEndOfTrack,
      checked: true,
      child: const Text(_kEndOfTrack),
    ),
    const PopupMenuDivider(),
    const PopupMenuItem<String>(value: _kCancel, child: Text(_kCancel)),
  ];
}

/// 统一外观的 `PopupMenuButton`（child 模式内部是裸 InkWell，
/// 不传 `borderRadius` 的话悬停高亮会是方块）。
Widget _popupDemo({
  required ValueChanged<String> onPick,
  AnimationStyle? style,
  IconData icon = Icons.more_horiz,
  String label = '打开',
  List<PopupMenuEntry<String>> Function()? entries,
}) {
  return PopupMenuButton<String>(
    tooltip: label,
    borderRadius: _kPillRadius,
    popUpAnimationStyle: style,
    onSelected: onPick,
    itemBuilder: (context) => (entries ?? _popupMenuEntries)(),
    child: _PillLabel(label: label, icon: icon),
  );
}

/// 与 app 里睡眠定时菜单同规模：12 项
/// （7 个预设 + 分隔线 + 两个模式 + 分隔线 + 取消）。
List<PopupMenuEntry<String>> _sleepTimerEntries() => <PopupMenuEntry<String>>[
  for (final minutes in _kSleepPresetMinutes)
    PopupMenuItem<String>(value: '$minutes 分钟', child: Text('$minutes 分钟')),
  const PopupMenuDivider(),
  const CheckedPopupMenuItem<String>(
    value: _kEndOfTrack,
    child: Text(_kEndOfTrack),
  ),
  const CheckedPopupMenuItem<String>(
    value: _kEndOfQueue,
    child: Text(_kEndOfQueue),
  ),
  const PopupMenuDivider(),
  const PopupMenuItem<String>(value: _kCancel, child: Text(_kCancel)),
];

/// 用普通 widget / `MenuItemButton` 拼的 `MenuAnchor`（供底部对照用）。
Widget _menuAnchorDemo({
  required ValueChanged<String> onPick,
  String label = 'MenuAnchor 12 项',
  int count = 12,
}) {
  return MenuAnchor(
    animated: true,
    consumeOutsideTap: true,
    style: const MenuStyle(
      alignment: AlignmentDirectional.topStart,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: _kPanelRadius),
      ),
      padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
      minimumSize: WidgetStatePropertyAll<Size>(Size(_kMenuWidth, 0)),
    ),
    crossAxisUnconstrained: false,
    menuChildren: [
      for (var i = 0; i < count; i++)
        MenuItemButton(
          onPressed: () => onPick('选项 ${i + 1}'),
          child: Text('选项 ${i + 1}'),
        ),
    ],
    builder: (context, controller, child) => _PillButton(
      label: label,
      icon: Icons.timer_outlined,
      onPressed: () =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}

/// 现场调参：时长 / 条目数 / 正向曲线 / 反向曲线 / 禁用动画。
class _PopupMenuTuning extends StatefulWidget {
  const _PopupMenuTuning({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  State<_PopupMenuTuning> createState() => _PopupMenuTuningState();
}

class _PopupMenuTuningState extends State<_PopupMenuTuning> {
  /// `AnimationStyle` 对弹出菜单**只生效** curve / reverseCurve / duration；
  /// `reverseDuration` 不会被读（`_PopupMenuRoute` 没覆写
  /// `reverseTransitionDuration`）→ 进和出永远一样长。
  double _ms = 300;
  int _count = 12;
  Curve _curve = Curves.linear;
  String _reverseKey = 'default';
  bool _noAnimation = false;

  static const List<(String, Curve)> _curveChoices = [
    ('linear（默认）', Curves.linear),
    ('easeOutCubic', Curves.easeOutCubic),
    ('fastOutSlowIn', Curves.fastOutSlowIn),
    ('easeOutExpo', Curves.easeOutExpo),
    ('emphasized', Curves.easeInOutCubicEmphasized),
    ('前段极快', Cubic(0.05, 0.95, 0.1, 1)),
  ];

  static const Map<String, String> _reverseChoices = {
    'default': '默认 Interval(0→2/3)',
    'linear': 'linear',
    'easeInCubic': 'easeInCubic',
    'easeOutCubic': 'easeOutCubic',
    'same': '与正向相同',
  };

  Curve? get _reverseCurve => switch (_reverseKey) {
    'default' => null,
    'linear' => Curves.linear,
    'easeInCubic' => Curves.easeInCubic,
    'easeOutCubic' => Curves.easeOutCubic,
    _ => _curve,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    final ms = _ms.round();
    // 面板与条目的阶梯都由 `unit = 1/(项数 + 1.5)` 决定：
    // 最后一条要等 (N/(N+1.5)) 才开始淡入。
    final lastStart = _count / (_count + 1.5);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'PopupMenuButton 现场调参',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: '打开',
                  borderRadius: _kPillRadius,
                  popUpAnimationStyle: _noAnimation
                      ? AnimationStyle.noAnimation
                      : AnimationStyle(
                          duration: Duration(milliseconds: ms),
                          curve: _curve,
                          reverseCurve: _reverseCurve,
                        ),
                  onSelected: widget.onPick,
                  itemBuilder: (context) => _popupEntriesForCount(_count),
                  child: const _PillLabel(label: '打开', icon: Icons.tune),
                ),
              ],
            ),
            _TuneSlider(
              label: '时长',
              value: _ms,
              min: 60,
              // 上限给到 2000ms：拖到最右就是"慢放"，能直接看出三层结构——
              // 面板淡入只占前 1/3、滑动一直跑到 0.889、最后一条从 0.889 才开始。
              max: 2000,
              divisions: 97,
              display: '$ms ms',
              onChanged: (value) => setState(() => _ms = value),
            ),
            _TuneSlider(
              label: '条目数',
              value: _count.toDouble(),
              min: 3,
              max: 13,
              divisions: 10,
              display: '$_count 项',
              onChanged: (value) => setState(() => _count = value.round()),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                '最后一条要等 ${(lastStart * 100).round()}%'
                '（≈ ${(lastStart * ms).round()}ms）才开始淡入——'
                '这是 unit = 1/(项数+1.5) 定的，项数越多越晚。',
                style: caption,
              ),
            ),
            _TuneRow(
              label: '正向曲线',
              child: DropdownButton<Curve>(
                value: _curve,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final (label, curve) in _curveChoices)
                    DropdownMenuItem<Curve>(value: curve, child: Text(label)),
                ],
                onChanged: (curve) {
                  if (curve != null) setState(() => _curve = curve);
                },
              ),
            ),
            _TuneRow(
              label: '反向曲线',
              child: DropdownButton<String>(
                value: _reverseKey,
                isDense: true,
                underline: const SizedBox.shrink(),
                items: [
                  for (final entry in _reverseChoices.entries)
                    DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                ],
                onChanged: (key) {
                  if (key != null) setState(() => _reverseKey = key);
                },
              ),
            ),
            Row(
              children: [
                SizedBox(
                  height: 32,
                  child: Checkbox(
                    value: _noAnimation,
                    visualDensity: VisualDensity.compact,
                    onChanged: (value) =>
                        setState(() => _noAnimation = value ?? false),
                  ),
                ),
                Text('禁用动画（noAnimation）', style: theme.textTheme.bodySmall),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '⚠️ 弹出菜单不读 AnimationStyle.reverseDuration → 进出永远同长；'
                '默认 reverseCurve 是 Interval(0, 2/3)，会让关闭的头 1/3 时长完全静止。',
                style: caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 调参面板里“条目数”那档用的菜单（统一命名，便于观察阶梯节奏）。
List<PopupMenuEntry<String>> _popupEntriesForCount(int count) => [
  for (var i = 0; i < count; i++)
    PopupMenuItem<String>(value: '选项 ${i + 1}', child: Text('选项 ${i + 1}')),
];

class _TuneSlider extends StatelessWidget {
  const _TuneSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label, style: style)),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: display,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 56,
          child: Text(display, textAlign: TextAlign.end, style: style),
        ),
      ],
    );
  }
}

class _TuneRow extends StatelessWidget {
  const _TuneRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: child),
          ),
        ],
      ),
    );
  }
}

// ─── 窗口底部对照：与播放条同位置、同菜单规模（12 项）──────────────

/// 把四种实现放在**窗口底部**（和播放条同一个位置）、都开 **12 项**菜单。
///
/// 上面列表里的对照都在窗口顶部、只有 5 项，看不出 `_PopupMenuRouteLayout`
/// "底边被钉住 → 整张菜单从下沿滑上来" 这个效应。
class _BottomBarLab extends StatelessWidget {
  const _BottomBarLab({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '窗口底部（与播放条同位置）· 12 项菜单。\n'
                '第 1 和第 4 项同为 300ms、同菜单，只差曲线（linear vs easeOutCubic）；'
                '注意菜单其实是「以底边为轴向上滑出来」的。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _popupDemo(
                    onPick: onPick,
                    icon: Icons.timer_outlined,
                    label: '默认 300ms',
                    entries: _sleepTimerEntries,
                  ),
                  _popupDemo(
                    onPick: onPick,
                    icon: Icons.timer_outlined,
                    label: '240ms 前段极快',
                    entries: _sleepTimerEntries,
                    style: const AnimationStyle(
                      duration: Duration(milliseconds: 240),
                      curve: Cubic(0.05, 0.95, 0.1, 1),
                    ),
                  ),
                  _menuAnchorDemo(onPick: onPick),
                  _popupDemo(
                    onPick: onPick,
                    icon: Icons.timer_outlined,
                    label: '300ms easeOutCubic',
                    entries: _sleepTimerEntries,
                    // 与第 1 项同控件、同长、同菜单，只把曲线从 linear 换成
                    // easeOutCubic —— 变量只剩曲线。
                    style: const AnimationStyle(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
