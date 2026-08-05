import 'package:flutter/material.dart';

import 'lyrics_view.dart';

/// 全屏歌词页（窄窗口下从播放页 AppBar 进入）。
class LyricsPage extends StatelessWidget {
  const LyricsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('歌词'), centerTitle: true),
      body: LyricsView(theme: Theme.of(context)),
    );
  }
}
