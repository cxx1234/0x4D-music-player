import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/widgets/cached_album_art.dart';
import 'package:txvziwm/widgets/song_info_card.dart';

import 'helpers/l10n.dart';

Song _song({String? album, int? albumId}) => Song(
  id: 1,
  title: 'Track',
  artist: 'Artist',
  album: album,
  albumId: albumId,
  filePath: '/music/track.flac',
  fileName: 'track.flac',
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2020),
  playCount: 0,
  isFavorite: 0,
  isAvailable: 1,
);

Widget _card(
  Song song, {
  bool isNarrow = false,
  bool compact = false,
  double? coverSize,
  VoidCallback? onOpenAlbum,
}) {
  return localizedApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 800,
          height: 600,
          child: SongInfoCard(
            song: song,
            theme: ThemeData(),
            isNarrow: isNarrow,
            compact: compact,
            coverSize: coverSize,
            onLike: () {},
            onOpenArtist: () {},
            onOpenAlbum: onOpenAlbum ?? () {},
            menuBuilder: (_) => const [],
            onMenuSelected: (song, value) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('resolveSongInfoCardLayout', () {
    test('迷你条固定 48', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: 832,
        compact: true,
      );
      expect(layout.form, SongInfoCardForm.compact);
      expect(layout.coverSize, kSongInfoCompactCover);
    });

    test('纵排宽度主导：688 宽 → 550', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: 832,
      );
      expect(layout.form, SongInfoCardForm.vertical);
      expect(layout.coverSize, 550);
    });

    test('普通窄卡恢复原来的 380 基准', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 440,
        contentHeight: 800,
      );
      expect(layout.form, SongInfoCardForm.vertical);
      expect(layout.coverSize, kSongInfoMinCover);
    });

    test('大窗口沿用原来的宽度比例（不封顶）', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 1200,
        contentHeight: 1500,
      );
      expect(layout.form, SongInfoCardForm.vertical);
      expect(layout.coverSize, 960);
    });

    test('2560 窗（内容宽 944）恢复原来的 755', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 944,
        contentHeight: 1200,
      );
      expect(layout.form, SongInfoCardForm.vertical);
      expect(layout.coverSize, 755);
    });

    test('高度充足时保持宽度主导', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: 652,
      );
      expect(layout.coverSize, 484);
    });

    test('高度不足时封面先收缩', () {
      expect(
        resolveSongInfoCardLayout(
          contentWidth: 688,
          contentHeight: 600,
        ).coverSize,
        432,
      );
      expect(
        resolveSongInfoCardLayout(
          contentWidth: 688,
          contentHeight: 560,
        ).coverSize,
        392,
      );
    });

    test('封面低于 380 基准时改横排', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: 500,
      );
      expect(layout.form, SongInfoCardForm.horizontal);
      expect(layout.coverSize, 275);
    });

    test('窄短窗（906 × 451）改用横排，不再挤成小封面纵排', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 906,
        contentHeight: 451,
      );
      expect(layout.form, SongInfoCardForm.horizontal);
      expect(layout.coverSize, 362);
    });

    test('阈值 548 保持纵排，低一像素切横排', () {
      final atThreshold = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: kSongInfoMinCover + kSongInfoVerticalTextHeight,
      );
      expect(atThreshold.form, SongInfoCardForm.vertical);
      expect(atThreshold.coverSize, kSongInfoMinCover);

      final belowThreshold = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: kSongInfoMinCover + kSongInfoVerticalTextHeight - 1,
      );
      expect(belowThreshold.form, SongInfoCardForm.horizontal);
      expect(belowThreshold.coverSize, 275);
    });

    test('横排封面受高度钳制', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: 200,
      );
      expect(layout.form, SongInfoCardForm.horizontal);
      expect(layout.coverSize, 200);
    });

    test('极窄内容宽不产生超出内容宽的封面', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 100,
        contentHeight: 500,
      );
      expect(layout.coverSize, lessThanOrEqualTo(100));
    });

    test('封面尺寸一律取整', () {
      final layout = resolveSongInfoCardLayout(
        contentWidth: 688,
        contentHeight: 900,
      );
      expect(layout.coverSize, layout.coverSize.floorToDouble());
    });
  });

  group('SongInfoCard cover', () {
    testWidgets('注入 coverSize 时按注入值渲染', (tester) async {
      await tester.pumpWidget(
        _card(_song(album: 'Album'), isNarrow: true, coverSize: 222),
      );
      final art = tester.widget<CachedAlbumArt>(find.byType(CachedAlbumArt));
      expect(art.size, 222);
    });

    testWidgets('点击封面打开专辑', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _card(
          _song(album: 'Album'),
          isNarrow: true,
          coverSize: 200,
          onOpenAlbum: () => opened++,
        ),
      );
      await tester.tap(find.byType(CachedAlbumArt));
      await tester.pump();
      expect(opened, 1);
    });

    testWidgets('悬停封面轻微放大', (tester) async {
      await tester.pumpWidget(
        _card(_song(album: 'Album'), isNarrow: true, coverSize: 200),
      );
      double coverScale() => tester
          .widget<AnimatedScale>(
            find
                .ancestor(
                  of: find.byType(CachedAlbumArt),
                  matching: find.byType(AnimatedScale),
                )
                .first,
          )
          .scale;
      expect(coverScale(), 1);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);
      await tester.pump();

      await gesture.moveTo(tester.getCenter(find.byType(CachedAlbumArt)));
      await tester.pump();
      expect(coverScale(), 1.03);

      await gesture.moveTo(const Offset(700, 500));
      await tester.pump();
      expect(coverScale(), 1);
    });

    testWidgets('无专辑信息时封面不可点击', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        _card(
          _song(),
          isNarrow: true,
          coverSize: 200,
          onOpenAlbum: () => opened++,
        ),
      );
      expect(
        find.ancestor(
          of: find.byType(CachedAlbumArt),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
      await tester.tap(find.byType(CachedAlbumArt));
      await tester.pump();
      expect(opened, 0);
    });
  });
}
