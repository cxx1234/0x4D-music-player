import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/widgets/song_tile.dart';

/// 当前播放高亮在各列表中的表现必须一致：
/// 底色/文字高亮由 [SongTile.isCurrentSong] 决定，
/// 封面播放中动画与行尾音量图标由「isCurrentSong && isPlaying」决定。
///
/// 回归背景：`isPlaying` 曾只在音乐库传入 → 封面「播放中」动画只出现在音乐库，
/// 专辑/歌手/收藏/播放列表详情里当前曲永远是音符角标 + 永远是暂停图标。
Song _song() => Song(
  id: 1,
  title: 'Track',
  artist: '歌手',
  album: '专辑',
  filePath: '/music/track.mp3',
  fileName: 'track.mp3',
  durationMs: 245000, // 显示为 4:05，供行尾图标间距断言定位
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2020),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
);

Future<void> _pump(
  WidgetTester tester, {
  required bool isCurrentSong,
  required bool isPlaying,
  String? leadingText,
  bool showCurrentIndicator = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SongTile(
          song: _song(),
          isCurrentSong: isCurrentSong,
          isPlaying: isPlaying,
          leadingText: leadingText,
          showCurrentIndicator: showCurrentIndicator,
        ),
      ),
    ),
  );
}

bool _selected(WidgetTester tester) =>
    tester.widget<ListTile>(find.byType(ListTile)).selected;

Finder _musicNote() => find.byIcon(Icons.music_note);
Finder _volumeUp() => find.byIcon(Icons.volume_up_rounded);
Finder _pause() => find.byIcon(Icons.pause_rounded);

void main() {
  testWidgets('非当前歌曲：无底色高亮、无任何播放态指示', (tester) async {
    await _pump(tester, isCurrentSong: false, isPlaying: false);

    expect(_selected(tester), isFalse);
    expect(_musicNote(), findsNothing);
    expect(_volumeUp(), findsNothing);
    expect(_pause(), findsNothing);
  });

  testWidgets('当前歌曲 + 播放中：封面播放中动画代替音符角标，行尾为音量图标', (tester) async {
    await _pump(tester, isCurrentSong: true, isPlaying: true);

    expect(_selected(tester), isTrue);
    expect(_volumeUp(), findsOneWidget);
    expect(_pause(), findsNothing);
    // 播放中时角标（右下角音符）应让位给播放中动画
    expect(_musicNote(), findsNothing);
  });

  testWidgets('当前歌曲 + 暂停：封面右下角音符角标 + 行尾暂停图标', (tester) async {
    await _pump(tester, isCurrentSong: true, isPlaying: false);

    expect(_selected(tester), isTrue);
    expect(_musicNote(), findsOneWidget);
    expect(_pause(), findsOneWidget);
    expect(_volumeUp(), findsNothing);
  });

  testWidgets('非当前歌曲即使误传 isPlaying 也不点亮（不出现播放中遮罩/音量图标）', (tester) async {
    await _pump(tester, isCurrentSong: false, isPlaying: true);

    expect(_selected(tester), isFalse);
    expect(_musicNote(), findsNothing);
    expect(_volumeUp(), findsNothing);
    expect(_pause(), findsNothing);
  });

  testWidgets('带序号 leading（专辑/播放列表详情）：行尾指示同样随播放态变化', (tester) async {
    await _pump(tester, isCurrentSong: true, isPlaying: true, leadingText: '3');

    expect(_selected(tester), isTrue);
    // 序号槽位替代封面，故没有封面角标/播放中动画；行尾仍须反映播放态
    expect(_musicNote(), findsNothing);
    expect(_volumeUp(), findsOneWidget);
  });

  testWidgets('队列（showCurrentIndicator: false）：不显示行尾指示图标', (tester) async {
    await _pump(
      tester,
      isCurrentSong: true,
      isPlaying: true,
      leadingText: '1',
      showCurrentIndicator: false,
    );

    expect(_selected(tester), isTrue);
    expect(_volumeUp(), findsNothing);
    expect(_pause(), findsNothing);
  });

  testWidgets('行尾播放态图标与右侧时长文本保持间距（不贴在一起）', (tester) async {
    await _pump(tester, isCurrentSong: true, isPlaying: true);

    final icon = tester.getRect(_volumeUp());
    final duration = tester.getRect(find.text('4:05'));
    expect(
      duration.left - icon.right,
      greaterThanOrEqualTo(12),
      reason: '图标与时长文本的间距不应小于 12（原为 8，视觉上像连在一起）',
    );
  });
}
