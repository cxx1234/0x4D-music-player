import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/widgets/context_menu.dart';
import 'package:txvziwm/widgets/song_tile.dart';

/// 歌曲行的鼠标右键（次级点击）：
/// - 行内**有**三点菜单时，右键必须打开**同一个** `PopupMenuButton`（位置/动画
///   与点三点一致），而不是另弹一份；
/// - 行内**没有**三点菜单时（播放队列），回调把行自己的 context 交给调用方；
/// - 两者都没有时不该多包一层手势、更不该崩。
Song _song(int id) => Song(
  id: id,
  title: 'Track $id',
  artist: 'Artist',
  album: 'Album',
  filePath: '/music/Track $id.mp3',
  fileName: 'Track $id.mp3',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2020),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
);

Future<void> _pumpRow(WidgetTester tester, SongTile tile) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListView.builder(
          itemExtent: SongTile.kRowHeight,
          itemCount: 1,
          itemBuilder: (context, index) => tile,
        ),
      ),
    ),
  );
}

/// 鼠标右键：按下并抬起鼠标次键。
///
/// 用 `TestPointer` 显式带上 `kSecondaryMouseButton`，才能走进
/// `GestureDetector.onSecondaryTap`（`tester.tap` 默认只发主键）。
Future<void> _secondaryTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder, buttons: kSecondaryMouseButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('有内层三点菜单的行：右键打开同一个菜单', (tester) async {
    await _pumpRow(
      tester,
      SongTile(
        song: _song(1),
        menuBuilder: (song) => const [
          PopupMenuItem(value: 'playNext', child: Text('下一首播放')),
          PopupMenuItem(value: 'favorite', child: Text('喜欢')),
        ],
      ),
    );

    expect(find.text('下一首播放'), findsNothing);

    // 右键在行**中间**（不是三点按钮上），菜单仍要弹在三点按钮那里。
    await _secondaryTap(tester, find.text('Track 1'));

    expect(find.text('下一首播放'), findsOneWidget);
    expect(find.text('喜欢'), findsOneWidget);
  });

  testWidgets('没有三点菜单的行：右键把行自己交给调用方（队列行走这条）', (tester) async {
    BuildContext? gotContext;
    Song? gotSong;
    await _pumpRow(
      tester,
      SongTile(
        song: _song(2),
        onSecondaryTap: (rowContext, song) {
          gotContext = rowContext;
          gotSong = song;
        },
      ),
    );

    // 不传 menuBuilder 就不该有那层手势时也不该崩。
    await _secondaryTap(tester, find.text('Track 2'));

    expect(gotSong?.id, 2);
    expect(gotContext, isNotNull);
    // 回调拿到的是行自己的 context —— 调用方据此算锚点，必须就是这一行的矩形。
    final rowRect = overlayRectOf(gotContext!);
    if (rowRect == null) fail('行矩形算不出来，右键菜单会锚到错的地方');
    expect(rowRect.height, SongTile.kRowHeight);
    expect(rowRect.width, tester.getRect(find.byType(SongTile)).width);
  });

  testWidgets('两个回调都没有的行：右键无事发生', (tester) async {
    await _pumpRow(tester, SongTile(song: _song(3)));

    await _secondaryTap(tester, find.text('Track 3'));

    expect(tester.takeException(), isNull);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
  });
}
