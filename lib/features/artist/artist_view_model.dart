import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/viewmodels/page_view_model.dart';

/// ViewModel for the Artists browse page.
class ArtistsViewModel extends PageViewModel {
  List<Artist> _artists = [];

  /// 每个歌手的歌曲/专辑统计（来自 DB 聚合，避免在内存里持有全量歌曲副本）。
  Map<int, ({int songCount, int albumCount})> _artistStats = {};

  bool _artistsLoaded = false;
  bool _statsLoaded = false;

  List<Artist> get artists => _artists;

  /// 歌手 [artist] 的歌曲/专辑计数（无记录视为 0/0）。
  ({int songCount, int albumCount}) statsFor(Artist artist) =>
      _artistStats[artist.id] ?? (songCount: 0, albumCount: 0);

  /// 订阅歌手列表与统计的实时查询：两者都到齐后才收起首载转圈，避免先显示
  /// 一排「0 首」再跳成真实计数。
  void start() {
    trackStream(ServiceLocator.songRepo.watchAllArtists(), (artists) {
      _artists = artists;
      _artistsLoaded = true;
      _finishLoadingIfReady();
      safeNotify();
    });
    trackStream(ServiceLocator.songRepo.watchArtistStats(), (stats) {
      _artistStats = stats;
      _statsLoaded = true;
      _finishLoadingIfReady();
      safeNotify();
    });
  }

  void _finishLoadingIfReady() {
    if (!_artistsLoaded || !_statsLoaded) return;
    setLoading(false);
  }
}
