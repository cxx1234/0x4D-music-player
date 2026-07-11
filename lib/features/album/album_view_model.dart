import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';

/// ViewModel for the Albums browse page.
class AlbumsViewModel extends ChangeNotifier {
  List<Album> _albums = [];
  List<Song> _songs = [];
  bool _loading = true;

  List<Album> get albums => _albums;
  List<Song> get songs => _songs;
  bool get loading => _loading;

  /// Loads all albums from the database.
  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      _albums = await ServiceLocator.songRepo.getAllAlbums();
      _songs = await ServiceLocator.songRepo.getAvailableSongs();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Returns the songs belonging to [album].
  List<Song> songsForAlbum(Album album) {
    return _songs.where((s) => s.albumId == album.id).toList();
  }
}
