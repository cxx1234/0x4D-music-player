import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/widgets/cached_album_art.dart';
import 'package:txvziwm/widgets/list_item_tile.dart';
import 'package:txvziwm/widgets/song_tile.dart';

/// 列表统一行高（与 `ListView.itemExtent: 72` 一致）。
const double _kRowExtent = 72;

/// 构造歌曲；[artist]/[album] 为 null 表示文件缺少对应 ID3 字段。
Song _song(int id, {String? title, String? artist, String? album}) {
  final t = title ?? 'Track $id';
  return Song(
    id: id,
    title: t,
    artist: artist,
    album: album,
    filePath: '/music/$t.mp3',
    fileName: '$t.mp3',
    hasEmbeddedArt: 0,
    hasEmbeddedLyrics: 0,
    dateAdded: DateTime(2020),
    playCount: 0,
    isFavorite: 0,
    isAvailable: 1,
  );
}

/// 真实列表环境：`itemExtent: 72` 会把每一行的高度紧约束为 72。
Future<void> _pumpList(
  WidgetTester tester,
  List<Song> songs, {
  bool showIndex = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          itemExtent: _kRowExtent,
          itemCount: songs.length,
          itemBuilder: (context, index) => SongTile(
            song: songs[index],
            leadingText: showIndex ? '${index + 1}' : null,
          ),
        ),
      ),
    ),
  );
}

/// 第 [index] 行的矩形。
Rect _rowRect(WidgetTester tester, int index) =>
    tester.getRect(find.byType(SongTile).at(index));

void main() {
  testWidgets('缺少 ID3（无歌手/专辑）的歌曲：标题与封面仍垂直居中', (tester) async {
    await _pumpList(tester, [_song(1, artist: null, album: null)]);

    final row = _rowRect(tester, 0);
    expect(row.height, _kRowExtent);

    // 标题应与整行同心中线对齐（ListTile 单行模式内容居中）。
    expect(
      tester.getRect(find.text('Track 1')).center.dy,
      closeTo(row.center.dy, 0.5),
    );
    // 行首序号槽位同理，不能被挤到上方。
    expect(
      tester.getRect(find.text('1')).center.dy,
      closeTo(row.center.dy, 0.5),
    );
  });

  testWidgets('有歌手/专辑的歌曲：内容垂直居中（回归保护）', (tester) async {
    await _pumpList(
      tester,
      [_song(1, artist: '歌手', album: '专辑')],
    );

    final row = _rowRect(tester, 0);
    expect(row.height, _kRowExtent);

    // 两行文本块整体居中：块中心 = 行中心。
    final titleRect = tester.getRect(find.text('Track 1'));
    final subtitleRect = tester.getRect(find.textContaining('歌手'));
    expect(
      (titleRect.top + subtitleRect.bottom) / 2,
      closeTo(row.center.dy, 0.5),
    );
  });

  testWidgets('有/无副标题的行高一致，内容都居中', (tester) async {
    await _pumpList(
      tester,
      [
        _song(1, artist: '歌手', album: '专辑'),
        _song(2, artist: null, album: null),
      ],
      showIndex: false,
    );
    final withMeta = _rowRect(tester, 0);
    final withoutMeta = _rowRect(tester, 1);
    expect(withMeta.height, _kRowExtent);
    expect(withoutMeta.height, _kRowExtent);

    // 封面（44）在两行中相对行中心的偏移应一致。
    final covers = find.byType(CachedAlbumArt);
    expect(
      tester.getRect(covers.at(0)).center.dy - withMeta.center.dy,
      closeTo(tester.getRect(covers.at(1)).center.dy - withoutMeta.center.dy, 0.5),
    );
  });

  testWidgets('ListItemTile 无副标题时同样保持行高与居中', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView.builder(
            itemExtent: _kRowExtent,
            itemCount: 2,
            itemBuilder: (context, index) => ListItemTile(
              leading: const SizedBox(width: 44, height: 44),
              title: 'Item $index',
              subtitle: index == 0 ? '副标题' : null,
            ),
          ),
        ),
      ),
    );

    for (var i = 0; i < 2; i++) {
      final rowFinder = find.byType(ListItemTile).at(i);
      final row = tester.getRect(rowFinder);
      expect(row.height, _kRowExtent, reason: '第 $i 行行高');
      final icon = find.descendant(
        of: rowFinder,
        matching: find.byType(SizedBox),
      );
      expect(
        tester.getRect(icon).center.dy,
        closeTo(row.center.dy, 0.5),
        reason: '第 $i 行行首图标居中',
      );
    }
  });
}
