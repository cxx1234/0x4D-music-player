import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/utils/logger.dart';
import 'song_info_data.dart';

/// 读取一首歌的信息面板数据；歌曲行已不存在时返回 null。
///
/// 唯一入口是歌曲 id（不是 `Song` 实体）：面板数据一律现取，将来换成独立
/// 窗口时同一入口只需换容器，见 `docs/UI-Rules.md` §18。
Future<SongInfoData?> loadSongInfo(int songId) async {
  final repository = ServiceLocator.songRepo;
  final song = await repository.getSongById(songId);
  if (song == null) {
    AppLogger.warning('SongInfo', 'Song $songId is no longer in the library');
    return null;
  }
  final albumId = song.albumId;
  final Album? album = albumId == null
      ? null
      : await repository.getAlbumById(albumId);
  return SongInfoData.fromSong(song, album: album);
}
