import 'dart:async';

import 'package:flutter_lyric/flutter_lyric.dart';

import 'player_service.dart';

/// 把 [PlayerService] 适配成 flutter_lyric 的逐帧进度源。
///
/// 控制器自己负责订阅与采样（只在歌词视图可见、应用在前台且正在播放时
/// 逐帧读取 [position]）；本类只转发现有播放器通知，不另建播放时钟。
class PlayerLyricProgressSource implements LyricProgressSource {
  PlayerLyricProgressSource(this._player) {
    _player.addListener(_onPlayerChanged);
  }

  final PlayerService _player;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Duration get position => _player.position;

  @override
  bool get isAdvancing => _player.isAdvancing;

  @override
  Stream<void> get changes => _changes.stream;

  void _onPlayerChanged() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void dispose() {
    _player.removeListener(_onPlayerChanged);
    _changes.close();
  }
}
