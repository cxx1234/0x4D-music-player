import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/features/song_info/song_info_data.dart';

Song _song({
  int? fileSize = 36544379,
  int? durationMs = 280013,
  int? bitrate = 705600,
  int? sampleRate = 44100,
  int? albumId,
  String? albumArtFilePath,
  int hasEmbeddedArt = 0,
  int hasEmbeddedLyrics = 0,
  String? lyricsFilePath,
  int isAvailable = 1,
  int isFavorite = 0,
  int playCount = 4,
}) {
  return Song(
    id: 7,
    title: '大地に咲く旋律',
    artist: '森永真由美',
    album: '大地に咲く旋律',
    albumId: albumId,
    trackNumber: 2,
    discNumber: 1,
    durationMs: durationMs,
    filePath: '/music/大地に咲く旋律.flac',
    fileName: '大地に咲く旋律.flac',
    fileSize: fileSize,
    lastModifiedMs: 1700000000000,
    year: 2019,
    genre: 'J-Pop',
    bitrate: bitrate,
    sampleRate: sampleRate,
    albumArtFilePath: albumArtFilePath,
    lyricsFilePath: lyricsFilePath,
    hasEmbeddedArt: hasEmbeddedArt,
    hasEmbeddedLyrics: hasEmbeddedLyrics,
    dateAdded: DateTime(2026, 11, 19),
    playCount: playCount,
    isFavorite: isFavorite,
    isAvailable: isAvailable,
  );
}

void main() {
  test('码率用文件平均码率，而不是 FLAC 的 PCM 位率', () {
    final data = SongInfoData.fromSong(_song());
    expect(data.bitrateBps, 1044077);
    expect(data.bitrateBps, isNot(705600));
  });

  test('专辑艺术家来自专辑行；没有专辑行时为空', () {
    final album = Album(
      id: 3,
      name: '大地に咲く旋律',
      albumArtist: '幽閉サテライト',
      songCount: 1,
    );
    expect(
      SongInfoData.fromSong(_song(albumId: 3), album: album).albumArtist,
      '幽閉サテライト',
    );
    expect(SongInfoData.fromSong(_song()).albumArtist, isNull);
  });

  test('空字符串标签归一为 null，避免信息面板出现空行', () {
    final song = _song(lyricsFilePath: '  ', albumArtFilePath: '');
    final data = SongInfoData.fromSong(song);
    expect(data.lyricsFilePath, isNull);
    expect(data.albumArtFilePath, isNull);
  });

  test('字段映射：格式、日期、收藏与可用性', () {
    final data = SongInfoData.fromSong(
      _song(isFavorite: 1, isAvailable: 0, hasEmbeddedLyrics: 1),
    );
    expect(data.fileType, 'FLAC');
    expect(data.modifiedAt, DateTime.fromMillisecondsSinceEpoch(1700000000000));
    expect(data.addedAt, DateTime(2026, 11, 19));
    expect(data.isFavorite, isTrue);
    expect(data.isAvailable, isFalse);
    expect(data.hasEmbeddedLyrics, isTrue);
    expect(data.playCount, 4);
    expect(data.trackNumber, 2);
    expect(data.discNumber, 1);
    expect(data.year, 2019);
  });
}
