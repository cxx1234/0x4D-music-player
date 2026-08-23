import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<Set<String>> indexNames(String table) async {
    final rows = await db.customSelect('PRAGMA index_list("$table")').get();
    return rows.map((r) => r.data['name'] as String).toSet();
  }

  test('新建库自动创建全部查询索引', () async {
    expect(
      await indexNames('songs'),
      containsAll([
        'idx_songs_avail_sort',
        'idx_songs_album_id',
        'idx_songs_artist_id',
        'idx_songs_fav_avail',
      ]),
    );
    expect(
      await indexNames('playlist_songs'),
      containsAll(['idx_plsongs_playlist', 'idx_plsongs_song']),
    );
    expect(await indexNames('albums'), contains('idx_albums_artist'));
  });

  test('索引幂等：重复建不报错（IF NOT EXISTS）', () async {
    // 直接再执行一次建索引语句应静默成功（迁移重试/重复升级安全）。
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_songs_avail_sort '
      'ON songs(is_available, title_sort_key)',
    );
    expect(await indexNames('songs'), contains('idx_songs_avail_sort'));
  });
}
