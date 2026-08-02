import 'package:flutter/material.dart';

import 'player_view_model.dart';
import 'queue_view.dart';

/// 全屏播放列表页（窄窗口下从播放页 AppBar 进入）。
class QueuePage extends StatefulWidget {
  const QueuePage({super.key});

  @override
  State<QueuePage> createState() => _QueuePageState();
}

class _QueuePageState extends State<QueuePage> {
  final _viewModel = PlayerViewModel();

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('播放列表'), centerTitle: true),
      body: QueueView(viewModel: _viewModel, theme: Theme.of(context)),
    );
  }
}
