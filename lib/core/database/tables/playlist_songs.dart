import 'package:drift/drift.dart';

import 'playlists.dart';

/// 播放列表与歌曲的多对多关联，`position` 决定在列表中的顺序。
///
/// `(playlistId, songId)` 唯一约束保证同一首歌不会重复加入同一播放列表。
class PlaylistSongs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get playlistId =>
      integer().references(Playlists, #id, onDelete: KeyAction.cascade)();
  IntColumn get songId => integer()();
  IntColumn get position => integer()();

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {playlistId, songId},
  ];
}
