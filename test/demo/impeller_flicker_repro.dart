// ============================================================================
// Impeller (macOS) 全窗口闪烁 —— 最小复现 App
// ============================================================================
// 目的：
//   用「运行时生成的纯色占位封面」复刻真实 app 里 CachedAlbumArt 的渲染路径：
//   Image.memory + frameBuilder(AnimatedOpacity 200ms 淡入) + GridView 滚动。
//   纯内存生成，零图片资源、零版权内容。
//
// 运行方式（把它当 App 入口，而不是 flutter test 测试）：
//   flutter run -d macos -t test/demo/impeller_flicker_repro.dart
//
// 注意：
//   1. 这个文件是「App 入口」，不是 flutter test 用例（别用 flutter test 跑它）。
//   2. flutter test 用软件渲染器，复现不了 Impeller 的 GPU 闪烁；
//      一定要用上面 `flutter run -t ...` 在 Intel Mac 上跑才能看到。
//   3. 发 issue 前请先确认：这个 demo 在你的 Intel Mac 上确实能复现闪烁。
// ============================================================================

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

void main() => runApp(const ReproApp());

class ReproApp extends StatelessWidget {
  const ReproApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Impeller flicker repro',
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

  /// 纯色方块 → PNG bytes（512×512 全尺寸解码，与真实 app 一致：不设 cacheWidth）。
  Future<Uint8List> _solidPng(Color color, {int size = 512}) async {
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
      appBar: AppBar(title: const Text('Impeller flicker repro')),
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
    return Card(
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Expanded(
            // 复刻 CachedAlbumArt 的淡入逻辑：frame==null 先透明，加载后 200ms 淡入。
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: child,
                );
              },
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
