import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/viewmodels/page_view_model.dart';

/// ViewModel for the Albums browse page.
class AlbumsViewModel extends PageViewModel {
  List<Album> _albums = [];

  List<Album> get albums => _albums;

  /// 订阅专辑实时查询：新增文件（扫描 / 文件夹监视）、删除文件、改标签后
  /// 自动更新，不再依赖页面切换或 watcher 事件手工重载。
  void start() {
    trackStream(ServiceLocator.songRepo.watchAllAlbums(), (albums) {
      _albums = albums;
      setLoading(false);
      safeNotify();
    });
  }
}
