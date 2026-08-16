import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/viewmodels/page_view_model.dart';

/// ViewModel for the Artists browse page.
class ArtistsViewModel extends PageViewModel {
  List<Artist> _artists = [];

  /// 每个歌手的歌曲/专辑统计（来自 DB 聚合，避免在内存里持有全量歌曲副本）。
  Map<int, ({int songCount, int albumCount})> _artistStats = {};

  List<Artist> get artists => _artists;

  /// 歌手 [artist] 的歌曲/专辑计数（无记录视为 0/0）。
  ({int songCount, int albumCount}) statsFor(Artist artist) =>
      _artistStats[artist.id] ?? (songCount: 0, albumCount: 0);

  /// Loads all artists from the database.
  Future<void> load() {
    return runLoad(() async {
      _artists = await ServiceLocator.songRepo.getAllArtists();
      _artistStats = await ServiceLocator.songRepo.getArtistStats();
    }, hasData: _artists.isNotEmpty);
  }
}
