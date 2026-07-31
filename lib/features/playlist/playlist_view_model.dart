import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';

/// ViewModel for the Playlists browse page.
class PlaylistsViewModel extends ChangeNotifier {
  List<Playlist> _playlists = [];
  Map<int, int> _songCounts = {};
  int _favoriteCount = 0;
  bool _loading = true;

  List<Playlist> get playlists => _playlists;
  int get favoriteCount => _favoriteCount;
  bool get loading => _loading;

  /// 某个播放列表的可用歌曲数。
  int songCountFor(Playlist playlist) => _songCounts[playlist.id] ?? 0;

  /// 加载播放列表列表与"我的收藏"数量。
  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      _playlists = await ServiceLocator.songRepo.getAllPlaylists();
      _songCounts = await ServiceLocator.songRepo.getPlaylistSongCounts();
      _favoriteCount = await ServiceLocator.songRepo.getFavoriteCount();
    } finally {
      _loading = false;
      notifyListeners();
    }
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
