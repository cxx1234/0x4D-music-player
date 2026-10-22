// 鼠标侧键 / 返回键探针（开发用入口，不属于 app 的 main）。
//
// 运行：
//   flutter run -d macos -t test/demo/input_probe.dart
//
// 为什么需要它：macOS 会把侧键作为 `NSEvent.otherMouseDown`（buttonNumber 3/4）
// 交给 app，但**绝大多数 app 不处理**，而 remap 工具（Mac Mouse Fix / BTT /
// SteerMouse…）的工作就是「把侧键翻译成别的东西」——翻译成什么由工具配置决定：
//
//   1. 原样透传按钮 4/5        → 这里看到 buttons 带 0x08 / 0x10
//   2. 合成快捷键（最常见）    → 这里看到一条 key 事件（⌘[ / ⌥← / …）
//   3. 合成滚动或手势          → 这里看到 scroll dx≠0
//   4. 什么都不发              → 这里什么都没有（工具没权限 / 没运行 / 被消费）
//
// 所以「不同 app 发的不一样」不是 macOS 的锅，是翻译结果不同。按一次侧键，看
// 下面出现了哪一行，就知道该接哪条路。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const InputProbeApp());

class InputProbeApp extends StatelessWidget {
  const InputProbeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Input Probe',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6E7BF2),
        useMaterial3: true,
      ),
      home: const InputProbePage(),
    );
  }
}

enum _Kind { pointer, scroll, panZoom, key }

@immutable
class _Entry {
  const _Entry({
    required this.kind,
    required this.title,
    required this.detail,
    this.highlight = false,
  });

  final _Kind kind;
  final String title;
  final String detail;

  /// 与「返回 / 前进」相关的那几种事件，用底色标出来，方便一眼找到。
  final bool highlight;
}

class InputProbePage extends StatefulWidget {
  const InputProbePage({super.key});

  @override
  State<InputProbePage> createState() => _InputProbePageState();
}

class _InputProbePageState extends State<InputProbePage> {
  static const int _kMaxEntries = 200;

  final _entries = <_Entry>[];

  int _backButtonCount = 0;
  int _forwardButtonCount = 0;
  int _browserBackKeyCount = 0;
  int _cmdBracketCount = 0;

  @override
  void initState() {
    super.initState();
    // 低层键盘钩子：不管焦点在哪个控件上都能看到全部按键。
    // 返回 false = 不消费，输入框 / 快捷键照常工作。
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  // ─── 事件采集 ──────────────────────────────────────────

  void _add(_Entry entry) {
    if (!mounted) return;
    setState(() {
      _entries.insert(0, entry);
      if (_entries.length > _kMaxEntries) _entries.removeLast();
    });
  }

  /// 事件里带的修饰键状态（KeyEvent 本身没有修饰键字段，取 HardwareKeyboard）。
  static String _modifierText() {
    final keyboard = HardwareKeyboard.instance;
    final pressed = [
      if (keyboard.isMetaPressed) 'meta',
      if (keyboard.isControlPressed) 'ctrl',
      if (keyboard.isAltPressed) 'alt',
      if (keyboard.isShiftPressed) 'shift',
    ];
    return pressed.isEmpty ? 'none' : pressed.join('+');
  }

  bool _onKey(KeyEvent event) {
    final isBrowserBack = event.logicalKey == LogicalKeyboardKey.browserBack;
    final isBrowserForward =
        event.logicalKey == LogicalKeyboardKey.browserForward;
    final isCmdBracket =
        event.logicalKey == LogicalKeyboardKey.bracketLeft &&
        HardwareKeyboard.instance.isMetaPressed;

    if (event is KeyDownEvent) {
      if (isBrowserBack) _browserBackKeyCount++;
      if (isCmdBracket) _cmdBracketCount++;
    }

    final phase = switch (event) {
      KeyDownEvent() => 'down',
      KeyUpEvent() => 'up',
      KeyRepeatEvent() => 'repeat',
      _ => '?',
    };
    final character = switch (event) {
      KeyDownEvent(:final character) => character,
      KeyRepeatEvent(:final character) => character,
      _ => null,
    };

    _add(
      _Entry(
        kind: _Kind.key,
        title: 'key $phase',
        detail:
            'logical=${event.logicalKey.debugName ?? event.logicalKey.keyLabel}'
            '  physical=${event.physicalKey.debugName ?? "?"}\n'
            'modifiers=${_modifierText()}  character="${character ?? ""}"',
        highlight: isBrowserBack || isBrowserForward || isCmdBracket,
      ),
    );
    return false;
  }

  // ─── 指针事件 ──────────────────────────────────────────

  String _buttonsText(int buttons) =>
      '0x${buttons.toRadixString(16).padLeft(2, '0')}';

  void _onPointerDown(PointerDownEvent event) {
    final buttons = event.buttons;
    if (buttons & kBackMouseButton != 0) _backButtonCount++;
    if (buttons & kForwardMouseButton != 0) _forwardButtonCount++;

    _add(
      _Entry(
        kind: _Kind.pointer,
        title: 'pointer down',
        detail:
            'buttons=${_buttonsText(buttons)}'
            '  (back=${buttons & kBackMouseButton != 0}'
            ' forward=${buttons & kForwardMouseButton != 0})'
            '  changed=0x${smallestButton(buttons).toRadixString(16)}'
            '  kind=${event.kind.name}\n'
            'pos=(${event.position.dx.toStringAsFixed(0)}, '
            '${event.position.dy.toStringAsFixed(0)})',
        highlight: buttons & (kBackMouseButton | kForwardMouseButton) != 0,
      ),
    );
  }

  void _onPointerUp(PointerUpEvent event) {
    final buttons = event.buttons;
    _add(
      _Entry(
        kind: _Kind.pointer,
        title: 'pointer up',
        detail: 'buttons=${_buttonsText(buttons)}  kind=${event.kind.name}',
        highlight: buttons & (kBackMouseButton | kForwardMouseButton) != 0,
      ),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta;
    _add(
      _Entry(
        kind: _Kind.scroll,
        title: 'scroll',
        detail:
            'dx=${delta.dx.toStringAsFixed(1)}  dy=${delta.dy.toStringAsFixed(1)}',
      ),
    );
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _add(
      _Entry(
        kind: _Kind.panZoom,
        title: 'pan/zoom start',
        detail:
            'pos=(${event.position.dx.toStringAsFixed(0)}, '
            '${event.position.dy.toStringAsFixed(0)})',
      ),
    );
  }

  void _clear() {
    setState(() {
      _entries.clear();
      _backButtonCount = 0;
      _forwardButtonCount = 0;
      _browserBackKeyCount = 0;
      _cmdBracketCount = 0;
    });
  }

  Future<void> _copyAll() async {
    final text = _entries.map((e) => '${e.title}\n${e.detail}').join('\n---\n');
    await Clipboard.setData(ClipboardData(text: text));
  }

  // ─── UI ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Listener(
      // Listener 不进手势竞技场：下面的「清空」按钮照常可点。
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: _onPanZoomStart,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('鼠标侧键 / 返回键探针', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                '把鼠标放在内容区（避开标题栏与红绿灯），按一下「后退」侧键，'
                '再按一下「前进」侧键 —— 看下面出现了哪一行。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CounterChip(label: '后退侧键 0x08', count: _backButtonCount),
                  _CounterChip(label: '前进侧键 0x10', count: _forwardButtonCount),
                  _CounterChip(
                    label: 'browserBack 键',
                    count: _browserBackKeyCount,
                  ),
                  _CounterChip(label: '⌘[ 组合', count: _cmdBracketCount),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _entries.isEmpty
                      ? Center(
                          child: Text(
                            '还没有事件 —— 按一下侧键试试',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _entries.length,
                          itemBuilder: (context, index) =>
                              _EntryRow(entry: _entries[index]),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '提示：如果一条事件都没有，检查 remap 工具是否在运行、'
                    '有没有「输入监控 / 辅助功能」权限。',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _entries.isEmpty ? null : _copyAll,
                    child: const Text('复制全部'),
                  ),
                  TextButton(onPressed: _clear, child: const Text('清空')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CounterChip extends StatelessWidget {
  const _CounterChip({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hit = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hit
            ? theme.colorScheme.tertiaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$label  × $count',
        style: theme.textTheme.labelMedium?.copyWith(
          color: hit ? theme.colorScheme.onTertiaryContainer : null,
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = entry.highlight
        ? theme.colorScheme.tertiaryContainer
        : Colors.transparent;
    return Container(
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.title,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            entry.detail,
            style: const TextStyle(fontFamily: 'Menlo', fontSize: 12),
          ),
        ],
      ),
    );
  }
}
