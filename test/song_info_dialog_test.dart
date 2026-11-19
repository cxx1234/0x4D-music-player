import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/features/song_info/song_info_data.dart';
import 'package:txvziwm/features/song_info/song_info_view.dart';

import 'helpers/l10n.dart';

SongInfoData _data({
  String? artist = 'Artist',
  String? album = 'Album',
  String? albumArtist,
  int? year,
  int? durationMs = 268000,
  int? bitrateBps = 1044077,
  int? sampleRate = 44100,
  int? fileSize = 10485760,
  bool isAvailable = true,
  bool hasEmbeddedLyrics = false,
  String? lyricsFilePath,
  int playCount = 3,
  bool isFavorite = false,
}) {
  return SongInfoData(
    title: 'Track',
    artist: artist,
    album: album,
    albumArtist: albumArtist,
    year: year,
    genre: null,
    trackNumber: null,
    discNumber: null,
    durationMs: durationMs,
    bitrateBps: bitrateBps,
    sampleRate: sampleRate,
    fileSize: fileSize,
    modifiedAt: null,
    addedAt: DateTime(2026, 11, 19),
    filePath: '/music/Track.flac',
    fileType: 'FLAC',
    playCount: playCount,
    isFavorite: isFavorite,
    isAvailable: isAvailable,
    hasEmbeddedLyrics: hasEmbeddedLyrics,
    lyricsFilePath: lyricsFilePath,
    albumArtFilePath: null,
    hasEmbeddedArt: false,
  );
}

Widget _view(SongInfoData data, {VoidCallback? onClose}) => localizedApp(
  home: Scaffold(
    body: Center(
      child: SongInfoView(data: data, onClose: onClose ?? () {}),
    ),
  ),
);

void main() {
  testWidgets('渲染文件 / 标签 / 播放三段与格式化后的值', (tester) async {
    await tester.pumpWidget(_view(_data(albumArtist: 'Various')));

    expect(find.text('Track'), findsNWidgets(2));
    expect(find.text('Artist · Album'), findsOneWidget);
    expect(find.text('文件'), findsOneWidget);
    expect(find.text('标签'), findsOneWidget);
    expect(find.text('播放'), findsOneWidget);

    expect(find.text('FLAC'), findsOneWidget);
    expect(find.text('1.04 Mbps'), findsOneWidget);
    expect(find.text('44.1 kHz'), findsOneWidget);
    expect(find.text('4:28'), findsOneWidget);
    expect(find.text('10.0 MB'), findsOneWidget);
    expect(find.text('专辑艺术家'), findsOneWidget);
    expect(find.text('Various'), findsOneWidget);
    expect(find.text('播放次数'), findsOneWidget);
    expect(find.text('关闭'), findsOneWidget);
  });

  testWidgets('空值行整行隐藏（年份 / 码率 / 歌词文件）', (tester) async {
    await tester.pumpWidget(
      _view(
        _data(
          year: null,
          durationMs: null,
          fileSize: null,
          bitrateBps: null,
          sampleRate: null,
        ),
      ),
    );

    expect(find.text('年份'), findsNothing);
    expect(find.text('平均码率'), findsNothing);
    expect(find.text('采样率'), findsNothing);
    expect(find.text('内嵌歌词'), findsNothing);
    expect(find.text('歌词文件'), findsNothing);
  });

  testWidgets('文件不可用时显示警告条', (tester) async {
    await tester.pumpWidget(_view(_data(isAvailable: false)));
    expect(find.textContaining('文件已不可用'), findsOneWidget);

    await tester.pumpWidget(_view(_data()));
    expect(find.textContaining('文件已不可用'), findsNothing);
  });

  testWidgets('复制路径写入剪贴板并短暂回显勾选', (tester) async {
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(_view(_data()));
    await tester.ensureVisible(find.byIcon(Icons.copy_rounded));
    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    final setData = calls.lastWhere((c) => c.method == 'Clipboard.setData');
    expect((setData.arguments as Map)['text'], '/music/Track.flac');
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    expect(find.byTooltip('已复制'), findsOneWidget);

    // 回显到期后恢复复制图标（同时避免测试结束时有挂起的 Timer）。
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('关闭按钮回调由容器注入', (tester) async {
    var closed = false;
    await tester.pumpWidget(_view(_data(), onClose: () => closed = true));
    await tester.tap(find.text('关闭'));
    await tester.pump();
    expect(closed, isTrue);
  });
}
