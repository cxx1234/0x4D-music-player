import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';

/// 定向按 id 集合查专辑（歌手详情派生专辑用，替代全表 getAllAlbums）。
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<int> seedAlbum(String name, {int? year}) async {
    return db.insertAlbum(
      AlbumsCompanion.insert(name: name, year: Value(year)),
    );
  }

  test('按 id 集合定向返回匹配专辑', () async {
    final a = await seedAlbum('Album A');
    final b = await seedAlbum('Album B');
    await seedAlbum('Album C');

    final albums = await db.getAlbumsByIds([a, b]);
    expect(albums.map((x) => x.name), unorderedEquals(['Album A', 'Album B']));
  });

  test('空集合短路返回空列表（drift IN () 不合法）', () async {
    await seedAlbum('Album A');
    expect(await db.getAlbumsByIds(const <int>[]), isEmpty);
  });

  test('含不存在 id 时仅返回存在的专辑', () async {
    final a = await seedAlbum('Album A');
    final albums = await db.getAlbumsByIds([a, 9999]);
    expect(albums.map((x) => x.id), [a]);
  });
}
