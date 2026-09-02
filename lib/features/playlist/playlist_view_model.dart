import 'package:drift/drift.dart' hide Column;

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/viewmodels/page_view_model.dart';

/// ViewModel for the Playlists browse page.
class PlaylistsViewModel extends PageViewModel {
  List<Playlist> _playlists = [];
  Map<int, int> _songCounts = {};
  int _favoriteCount = 0;

  List<Playlist> get playlists => _playlists;
  int get favoriteCount => _favoriteCount;

  /// 正在进行的加载（供 [ensureLoaded] 复用，避免与首载并发双跑）。
  Future<void>? _inflight;

  /// 某个播放列表的可用歌曲数。
  int songCountFor(Playlist playlist) => _songCounts[playlist.id] ?? 0;

  /// 记录正在进行的加载，返回完成时清空 [_inflight] 的包装 future。
  Future<void> _track(Future<void> future) {
    _inflight = future;
    return future.whenComplete(() {
      if (identical(_inflight, future)) _inflight = null;
    });
  }

  /// 加载播放列表列表与"我的收藏"数量（供页面刷新，总是强制重查）。
  Future<void> load() {
    return _track(runLoad(_doLoad, hasData: _playlists.isNotEmpty));
  }

  Future<void> _doLoad() async {
    _playlists = await ServiceLocator.songRepo.getAllPlaylists();
    _songCounts = await ServiceLocator.songRepo.getPlaylistSongCounts();
    _favoriteCount = await ServiceLocator.songRepo.getFavoriteCount();
  }

  /// 数据已就绪立即返回；否则等待正在进行的加载或补一次加载。
  ///
  /// macOS 菜单动作（导出/导入）可能在页面首次构建、数据尚未加载完成时
  /// 到达，直接读 [_playlists] 会误判为空（如「没有可导出的播放列表」）。
  /// 动作处理前先 await 本方法确保数据到位。
  Future<void> ensureLoaded() {
    if (_playlists.isNotEmpty) return Future.value();
    return _inflight ?? _track(_doLoad());
  }

  /// 新建播放列表，返回新 id。
  Future<int> createPlaylist(String name) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return ServiceLocator.songRepo.insertPlaylist(
      PlaylistsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
  }

  Future<bool> renamePlaylist(int id, String name) async {
    final ok = await ServiceLocator.songRepo.updatePlaylist(
      PlaylistsCompanion(
        name: Value(name),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
      id,
    );
    await load();
    return ok;
  }

  Future<void> deletePlaylist(int id) async {
    await ServiceLocator.songRepo.deletePlaylist(id);
    await load();
  }
}
