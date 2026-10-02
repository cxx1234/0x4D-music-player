// ============================================================================
// Impeller (macOS) —— 性能版（测帧率用，非复现版）
// ============================================================================
// 说明：
//   这是 impeller_flicker_repro.dart 的「性能优化拷贝」，用于在 main 分支
//   上测真实帧率。原文件保持不动（它是 #191538 的复现脚本，要保留原样）。
//
// 与复现版的三处差异（目的：降低解码量、减少滚动期开销）：
//   1. 生成图尺寸 512 → 256（解码量降 4 倍）
//   2. Image.memory 加 cacheWidth/cacheHeight（按显示尺寸解码，ImageCache 存小图）
//   3. 建议用 --release 跑，否则 debug 帧率天然很低，看不出优化效果
//
// 额外：kUseShadows 控制「底部投影（3 条无 blur 实线）」开关，kUseFade 控制淡入。
//       blurRadius:0 的 BoxShadow 是纯色填充，不触发 SDF blur，弱 GPU 近零成本。
//       改完 const 后热重启即可，标题会显示当前组合。
//
// 运行方式（App 入口，不是 flutter test）：
//   flutter run --release -d macos -t test/demo/impeller_flicker_repro_perf.dart
//
// ⚠️ 注意：
//   - 本文件是「App 入口」，别用 flutter test 跑它。
//   - 测的是"main 分支 + Impeller 下滚动是否流畅"，不代表能复现 3.47 的闪烁。
// ============================================================================

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 封面解码尺寸（按网格里实际显示 ~150–200px 取 256 即可）。
const int _kCoverSize = 256;

/// A/B 开关①：卡片底部投影（3 条无 blur 实线）。true=显示 / false=纯平面。
const bool kUseShadows = true;

/// A/B 开关②：200ms 淡入（AnimatedOpacity）。true=保留 / false=去掉。
const bool kUseFade = true;

/// 方案 B：底部投影（3 条无 blur 实线，偏移递增、透明度递减）。
/// blurRadius:0 = 纯色填充，不触发 SDF blur，弱 GPU 上近乎零成本。
const List<BoxShadow> _kBottomDropShadow = [
  BoxShadow(color: Color(0x1A000000), blurRadius: 0, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x12000000), blurRadius: 0, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x0A000000), blurRadius: 0, offset: Offset(0, 3)),
];

void main() => runApp(const ReproApp());

class ReproApp extends StatelessWidget {
  const ReproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impeller flicker repro (perf)',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Uint8List> _covers = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  /// 生成 60 张纯色占位封面（确保能滚出好几屏）。
  Future<void> _generate() async {
    const palette = [
      Color(0xFFE53935),
      Color(0xFFD81B60),
      Color(0xFF8E24AA),
      Color(0xFF3949AB),
      Color(0xFF1E88E5),
      Color(0xFF00897B),
      Color(0xFF43A047),
      Color(0xFFFB8C00),
      Color(0xFF6D4C41),
    ];
    for (var i = 0; i < 60; i++) {
      _covers.add(await _solidPng(palette[i % palette.length]));
    }
    if (mounted) setState(() => _ready = true);
  }

  /// 纯色方块 → PNG bytes（256×256，解码量只有 512 版的 1/4）。
  Future<Uint8List> _solidPng(Color color, {int size = _kCoverSize}) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = color,
    );
    final image = await recorder.endRecording().toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        // 标题里带上 A/B 组合，录屏/截图可自证配置。
        title: Text(
          'perf [shadows=${kUseShadows ? 'on' : 'off'}, '
          'fade=${kUseFade ? 'on' : 'off'}]',
        ),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 200,
          childAspectRatio: 0.76,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _covers.length,
        itemBuilder: (context, i) =>
            _Cover(bytes: _covers[i], title: '专辑 ${i + 1}'),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.bytes, required this.title});

  final Uint8List bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        // kUseShadows=true → 底部投影（3 条实线）；false → 纯平面。
        boxShadow: kUseShadows ? _kBottomDropShadow : null,
      ),
      child: Column(
        children: [
          Expanded(
            // 按显示尺寸解码：cacheWidth/cacheHeight 让 ImageCache 只存小图，
            // 滚动重建时不重解码大图。淡入由 kUseFade 控制（复现版同款）。
            child: Image.memory(
              bytes,
              cacheWidth: _kCoverSize,
              cacheHeight: _kCoverSize,
              fit: BoxFit.cover,
              frameBuilder: kUseFade
                  ? (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: child,
                      );
                    }
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
