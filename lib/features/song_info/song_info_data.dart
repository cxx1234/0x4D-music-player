import 'package:flutter/foundation.dart';

import '../../core/database/database.dart';
import '../../core/utils/display_format.dart';

/// 歌曲信息面板的只读快照。
///
/// 刻意与 [Song] / 数据库解耦，字段扁平且都是可序列化的基础类型：将来若把
/// 面板搬进独立窗口（另一个 Flutter engine），整份数据可以原样传过去，
/// `SongInfoView` 不需要改动。见 `docs/UI-Rules.md` §18。
///
/// Phase 2 的技术字段（位深 / 声道 / ALAC-vs-AAC，解析器尚未暴露）就加在这里：
/// 新字段保持可空，View 里对应 `_InfoRow` 在值为 null 时整行自动隐藏。
/// 见 `docs/TODO.md` §5。
@immutable
class SongInfoData {
  const SongInfoData({
    required this.title,
    required this.artist,
    required this.album,
    required this.albumArtist,
    required this.year,
    required this.genre,
    required this.trackNumber,
    required this.discNumber,
    required this.durationMs,
    required this.bitrateBps,
    required this.sampleRate,
    required this.fileSize,
    required this.modifiedAt,
    required this.addedAt,
    required this.filePath,
    required this.fileType,
    required this.playCount,
    required this.isFavorite,
    required this.isAvailable,
    required this.hasEmbeddedLyrics,
    required this.lyricsFilePath,
    required this.albumArtFilePath,
    required this.hasEmbeddedArt,
  });

  final String title;
  final String? artist;
  final String? album;

  /// 专辑级艺术家标签（来自 `albums.album_artist`），不是歌曲的 [artist]。
  final String? albumArtist;
  final int? year;
  final String? genre;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMs;

  /// 平均码率（`文件大小 × 8 ÷ 时长`），不是解析器给的位率。
  final int? bitrateBps;
  final int? sampleRate;
  final int? fileSize;
  final DateTime? modifiedAt;
  final DateTime addedAt;
  final String filePath;

  /// 扩展名大写（`FLAC` / `MP3` / `M4A`）；无扩展名时为空串。
  final String fileType;
  final int playCount;
  final bool isFavorite;
  final bool isAvailable;
  final bool hasEmbeddedLyrics;
  final String? lyricsFilePath;
  final String? albumArtFilePath;
  final bool hasEmbeddedArt;

  /// 由歌曲行（+ 可选的专辑行）生成面板数据。
  factory SongInfoData.fromSong(Song song, {Album? album}) {
    return SongInfoData(
      title: song.title,
      artist: _trimmed(song.artist),
      album: _trimmed(song.album),
      albumArtist: _trimmed(album?.albumArtist),
      year: song.year,
      genre: _trimmed(song.genre),
      trackNumber: song.trackNumber,
      discNumber: song.discNumber,
      durationMs: song.durationMs,
      bitrateBps: averageBitrateBps(
        fileSize: song.fileSize,
        durationMs: song.durationMs,
        fallbackBps: song.bitrate,
      ),
      sampleRate: song.sampleRate,
      fileSize: song.fileSize,
      modifiedAt: _dateFromEpochMs(song.lastModifiedMs),
      addedAt: song.dateAdded,
      filePath: song.filePath,
      fileType: fileTypeLabel(song.fileName),
      playCount: song.playCount,
      isFavorite: song.isFavorite == 1,
      isAvailable: song.isAvailable == 1,
      hasEmbeddedLyrics: song.hasEmbeddedLyrics == 1,
      lyricsFilePath: _trimmed(song.lyricsFilePath),
      albumArtFilePath: _trimmed(song.albumArtFilePath),
      hasEmbeddedArt: song.hasEmbeddedArt == 1,
    );
  }
}

String? _trimmed(String? value) {
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

DateTime? _dateFromEpochMs(int? milliseconds) {
  if (milliseconds == null || milliseconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
