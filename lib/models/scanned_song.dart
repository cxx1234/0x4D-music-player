import 'dart:typed_data';

/// Represents a scanned audio file with its metadata.
class ScannedSong {
  final String filePath;
  final String fileName;
  final int fileSize;

  /// 文件最后修改时间(epoch ms),用于扫描变化检测。
  final int? lastModifiedMs;
  final String title;
  final String? artist;

  /// 专辑艺术家（独立标签，合集专辑区分于歌曲歌手）。
  final String? albumArtist;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMs;
  final int? year;
  final String? genre;
  final int? bitrate;
  final int? sampleRate;
  final String mimeType;

  /// Raw embedded album art bytes, if any.
  ///
  /// The caller (e.g. [SongRepository]) is responsible for caching this
  /// to disk with an album-keyed hash to avoid duplicates.
  final Uint8List? pictureBytes;

  /// MIME type of [pictureBytes], e.g. `"image/jpeg"`, `"image/png"`.
  final String? pictureMimeType;

  /// Whether the source audio file contains embedded album art.
  final bool hasEmbeddedArt;

  /// Path to an external `.lrc` lyrics file found alongside the audio file.
  final String? lyricsFilePath;

  const ScannedSong({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.lastModifiedMs,
    required this.title,
    this.artist,
    this.albumArtist,
    this.album,
    this.trackNumber,
    this.discNumber,
    this.durationMs,
    this.year,
    this.genre,
    this.bitrate,
    this.sampleRate,
    required this.mimeType,
    this.pictureBytes,
    this.pictureMimeType,
    this.hasEmbeddedArt = false,
    this.lyricsFilePath,
  });
}
