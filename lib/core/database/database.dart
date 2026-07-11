import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/albums.dart';
import 'tables/artists.dart';
import 'tables/songs.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Songs, Albums, Artists])
class FlutterMusicDatabase extends _$FlutterMusicDatabase {
  FlutterMusicDatabase(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from == 1) {
          await m.addColumn(songs, songs.isAvailable);
        }
        if (from <= 2) {
          await m.createTable(artists);
          await m.createTable(albums);
          await m.addColumn(songs, songs.artistId);
          await m.addColumn(songs, songs.albumId);
        }
      },
    );
  }

  static Future<FlutterMusicDatabase> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbFile = File(p.join(dir.path, 'music_library.db'));
    return FlutterMusicDatabase(NativeDatabase(dbFile, logStatements: true));
  }

  // ─── CRUD ───────────────────────────────────────────────

  Future<List<Song>> getAllSongs() => select(songs).get();

  Stream<List<Song>> watchAllSongs() => select(songs).watch();

  Future<Song?> getSongById(int id) =>
      (select(songs)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> insertSong(SongsCompanion entry) => into(songs).insert(entry);

  Future<int> insertSongOnConflictReplace(SongsCompanion entry) =>
      into(songs).insertOnConflictUpdate(entry);

  Future<int> deleteSong(Song song) => delete(songs).delete(song);

  Future<List<Song>> searchSongs(String query) {
    final pattern = '%$query%';
    return (select(songs)..where(
          (t) =>
              t.title.like(pattern) |
              t.artist.like(pattern) |
              t.album.like(pattern),
        ))
        .get();
  }

  Future<List<Song>> getSongsByFolder(String folderPath) {
    final pattern = '$folderPath%';
    return (select(songs)..where((t) => t.filePath.like(pattern))).get();
  }

  Future<Song?> getSongByFilePath(String filePath) => (select(
    songs,
  )..where((t) => t.filePath.equals(filePath))).getSingleOrNull();

  Future<int> getSongCount() async {
    final result = await customSelect('SELECT COUNT(*) FROM songs').getSingle();
    return result.read<int>('COUNT(*)');
  }

  Future<int> toggleFavorite(int id) {
    return transaction(() async {
      final song = await getSongById(id);
      if (song == null) return 0;
      final newValue = song.isFavorite == 1 ? 0 : 1;
      return (update(songs)..where((t) => t.id.equals(id))).write(
        SongsCompanion(isFavorite: Value(newValue)),
      );
    });
  }

  Future<int> incrementPlayCount(int id) {
    return transaction(() async {
      final song = await getSongById(id);
      if (song == null) return 0;
      return (update(songs)..where((t) => t.id.equals(id))).write(
        SongsCompanion(playCount: Value(song.playCount + 1)),
      );
    });
  }

  // ─── File state sync ────────────────────────────────────

  Future<List<String>> getAllFilePaths() async {
    return (select(
      songs,
    )..where((t) => t.isAvailable.equals(1))).map((s) => s.filePath).get();
  }

  Future<List<String>> getFolderFilePaths(String folderPath) async {
    final pattern = '$folderPath%';
    return (select(songs)
          ..where((t) => t.filePath.like(pattern) & t.isAvailable.equals(1)))
        .map((s) => s.filePath)
        .get();
  }

  Future<int> markAsUnavailable(List<String> filePaths) async {
    return (update(songs)..where((t) => t.filePath.isIn(filePaths))).write(
      SongsCompanion(isAvailable: const Value(0)),
    );
  }

  Future<int> markAsAvailable(String filePath) async {
    return (update(songs)..where((t) => t.filePath.equals(filePath))).write(
      SongsCompanion(isAvailable: const Value(1)),
    );
  }

  Future<int> deleteFolderSongs(String folderPath) async {
    final pattern = '$folderPath%';
    return (delete(songs)..where((t) => t.filePath.like(pattern))).go();
  }

  Future<List<Song>> getUnavailableSongs() {
    return (select(songs)..where((t) => t.isAvailable.equals(0))).get();
  }

  Future<List<Song>> getAvailableSongs() {
    return (select(songs)..where((t) => t.isAvailable.equals(1))).get();
  }

  // ─── Album queries ──────────────────────────────────────

  Future<List<Album>> getAllAlbums() => select(albums).get();

  Stream<List<Album>> watchAllAlbums() => select(albums).watch();

  Future<Album?> getAlbumById(int id) =>
      (select(albums)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Album?> getAlbumByNameAndArtist(String name, int artistId) =>
      (select(albums)
            ..where((t) => t.name.equals(name) & t.artistId.equals(artistId)))
          .getSingleOrNull();

  Future<int> insertAlbum(AlbumsCompanion entry) => into(albums).insert(entry);

  Future<int> updateAlbum(AlbumsCompanion entry, int id) =>
      (update(albums)..where((t) => t.id.equals(id))).write(entry);

  Future<List<Song>> getSongsByAlbum(int albumId) =>
      (select(songs)..where((t) => t.albumId.equals(albumId))).get();

  Stream<List<Song>> watchSongsByAlbum(int albumId) =>
      (select(songs)..where((t) => t.albumId.equals(albumId))).watch();

  // ─── Artist queries ─────────────────────────────────────

  Future<List<Artist>> getAllArtists() => select(artists).get();

  Stream<List<Artist>> watchAllArtists() => select(artists).watch();

  Future<Artist?> getArtistById(int id) =>
      (select(artists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Artist?> getArtistByName(String name) =>
      (select(artists)..where((t) => t.name.equals(name))).getSingleOrNull();

  Future<int> insertArtist(ArtistsCompanion entry) =>
      into(artists).insert(entry);

  Future<int> updateArtist(ArtistsCompanion entry, int id) =>
      (update(artists)..where((t) => t.id.equals(id))).write(entry);

  Future<List<Song>> getSongsByArtist(int artistId) =>
      (select(songs)..where((t) => t.artistId.equals(artistId))).get();

  Stream<List<Song>> watchSongsByArtist(int artistId) =>
      (select(songs)..where((t) => t.artistId.equals(artistId))).watch();

  Future<List<Album>> getAlbumsByArtist(int artistId) =>
      (select(albums)..where((t) => t.artistId.equals(artistId))).get();
}
