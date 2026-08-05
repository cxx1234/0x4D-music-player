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

  /// Returns albums that [artist] has songs in.
  ///
  /// Derived from the artist's songs (grouped by albumId) so compilation /
  /// multi-artist albums appear under every contributing artist, consistent
  /// with the artist detail page.
  List<Album> albumsForArtist(Artist artist) {
    final albumById = {for (final a in _albums) a.id: a};
    final albumsById = <int, Album>{};
    for (final s in _songs) {
      if (s.artistId != artist.id) continue;
      final albumId = s.albumId;
      if (albumId == null) continue;
      final album = albumById[albumId];
      if (album != null) albumsById[albumId] = album;
    }
    return albumsById.values.toList();
  }

  /// Returns songs belonging to [artist].
  List<Song> songsForArtist(Artist artist) {
    return _songs.where((s) => s.artistId == artist.id).toList();
  }
}
