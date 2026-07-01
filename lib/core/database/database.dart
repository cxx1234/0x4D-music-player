import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables/songs.dart';

part 'database.g.dart';

@DriftDatabase(tables: [Songs])
class FlutterMusicDatabase extends _$FlutterMusicDatabase {
  FlutterMusicDatabase(super.e);

  @override
  int get schemaVersion => 1;

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
}
