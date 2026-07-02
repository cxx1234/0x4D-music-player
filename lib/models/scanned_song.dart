/// Represents a scanned audio file with its metadata.
class ScannedSong {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String title;
  final String? artist;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final int? durationMs;
  final int? year;
  final String? genre;
  final int? bitrate;
  final int? sampleRate;
  final String mimeType;

  const ScannedSong({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.title,
    this.artist,
    this.album,
    this.trackNumber,
    this.discNumber,
    this.durationMs,
    this.year,
    this.genre,
    this.bitrate,
    this.sampleRate,
    required this.mimeType,
  });
}
