import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';

/// ViewModel for the Artists browse page.
class ArtistsViewModel extends ChangeNotifier {
  List<Artist> _artists = [];
  List<Album> _albums = [];
  List<Song> _songs = [];
  bool _loading = true;

  List<Artist> get artists => _artists;
  List<Album> get albums => _albums;
  List<Song> get songs => _songs;
  bool get loading => _loading;

  /// Loads all artists from the database.
  Future<void> load() async {
    _loading = true;
    notifyListeners();

    try {
      _artists = await ServiceLocator.songRepo.getAllArtists();
      _albums = await ServiceLocator.songRepo.getAllAlbums();
      _songs = await ServiceLocator.songRepo.getAvailableSongs();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Returns albums belonging to [artist].
  List<Album> albumsForArtist(Artist artist) {
    return _albums.where((a) => a.artistId == artist.id).toList();
  }

  /// Returns songs belonging to [artist].
  List<Song> songsForArtist(Artist artist) {
    return _songs.where((s) => s.artistId == artist.id).toList();
  }
}
