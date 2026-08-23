import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../core/viewmodels/page_view_model.dart';

/// ViewModel for the Albums browse page.
class AlbumsViewModel extends PageViewModel {
  List<Album> _albums = [];

  List<Album> get albums => _albums;

  /// Loads all albums from the database.
  Future<void> load() {
    return runLoad(() async {
      _albums = await ServiceLocator.songRepo.getAllAlbums();
    }, hasData: _albums.isNotEmpty);
  }
}
