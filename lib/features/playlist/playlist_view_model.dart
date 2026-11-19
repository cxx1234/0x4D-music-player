import 'dart:async';

import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/viewmodels/page_view_model.dart';

class PlaylistsViewModel extends PageViewModel {
  List<Playlist> _playlists = [];
  Map<int, int> _songCounts = {};
  int _favoriteCount = 0;

  bool _playlistsLoaded = false;
  bool _songCountsLoaded = false;
  bool _favoriteCountLoaded = false;

  /// 播放列表首帧数据到达信号（供 [ensureLoaded] 等待）。
  final Completer<void> _playlistsReady = Completer<void>();

  List<Playlist> get playlists => _playlists;
  int get favoriteCount => _favoriteCount;

  /// 某个播放列表的可用歌曲数。
  int songCountFor(Playlist playlist) => _songCounts[playlist.id] ?? 0;

  /// 订阅播放列表 / 各列表歌曲数 / 收藏数的实时查询。
  ///
  /// 三份数据都到齐后才收起首载转圈：否则会先渲染一排「0 首」再跳成真实值。
  void start() {
    final repo = ServiceLocator.songRepo;
    trackStream(repo.watchAllPlaylists(), (playlists) {
      _playlists = playlists;
      _playlistsLoaded = true;
      if (!_playlistsReady.isCompleted) _playlistsReady.complete();
      _finishLoadingIfReady();
      safeNotify();
    });
    trackStream(repo.watchPlaylistSongCounts(), (counts) {
      _songCounts = counts;
      _songCountsLoaded = true;
      _finishLoadingIfReady();
      safeNotify();
    });
    trackStream(repo.watchFavoriteCount(), (count) {
      _favoriteCount = count;
      _favoriteCountLoaded = true;
      _finishLoadingIfReady();
      safeNotify();
    });
  }

  void _finishLoadingIfReady() {
    if (!_playlistsLoaded || !_songCountsLoaded || !_favoriteCountLoaded) {
      return;
    }
    setLoading(false);
  }

  /// 播放列表数据已就绪立即返回；否则等待首帧到达。
  ///
  /// macOS 菜单动作（导出/导入）可能在页面首次构建、数据尚未加载完成时
  /// 到达，直接读 [_playlists] 会误判为空（如「没有可导出的播放列表」）。
  Future<void> ensureLoaded() =>
      _playlistsReady.isCompleted ? Future.value() : _playlistsReady.future;

  /// 新建播放列表，返回新 id。
  Future<int> createPlaylist(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ServiceLocator.songRepo.insertPlaylist(
      PlaylistsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
  }

  Future<bool> renamePlaylist(int id, String name) {
    return ServiceLocator.songRepo.updatePlaylist(
      PlaylistsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
      id,
    );
  }

  Future<void> deletePlaylist(int id) =>
      ServiceLocator.songRepo.deletePlaylist(id);

  @override
  void dispose() {
    // 页面销毁后仍未拿到首帧（如启动即退出）：放行等待方，避免菜单动作
    // 永远 await 在一个不会再完成的 Future 上。
    if (!_playlistsReady.isCompleted) _playlistsReady.complete();
    super.dispose();
  }
}
