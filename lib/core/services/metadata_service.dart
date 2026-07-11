import 'dart:io';
import 'dart:typed_data';

import 'package:metadata_god/metadata_god.dart';
import 'package:path/path.dart' as p;

import '../../models/scanned_song.dart';
import '../constants/mime_types.dart';

/// Parses audio metadata from files using [metadata_god].
class MetadataService {
  /// Parses metadata from a single audio file.
  ///
  /// If the audio file has no [title] tag, the file name (without extension)
  /// is used as a fallback.
  ///
  /// Returns raw embedded album art bytes via [pictureBytes] / [pictureMimeType].
  /// The caller (e.g. [SongRepository]) is responsible for caching the art
  /// with an album-keyed hash to avoid duplicates.
  ///
  /// Also looks for an external `.lrc` lyrics file alongside the audio file.
  Future<ScannedSong> parse(String filePath) async {
    final file = File(filePath);
    final metadata = await MetadataGod.readMetadata(file: filePath);

    final fileName = p.basename(filePath);
    final title = (metadata.title?.trim().isNotEmpty == true)
        ? metadata.title!.trim()
        : p.basenameWithoutExtension(filePath);

    // ── Extract embedded album art (raw bytes, no caching) ──
    Uint8List? pictureBytes;
    String? pictureMimeType;
    var hasEmbeddedArt = false;

    if (metadata.picture != null) {
      pictureBytes = metadata.picture!.data;
      pictureMimeType = metadata.picture!.mimeType;
      hasEmbeddedArt = true;
    }

    // ── Look for external .lrc lyrics file ────────────────
    final lyricsPath = _findLrcFile(filePath);

    return ScannedSong(
      filePath: filePath,
      fileName: fileName,
      fileSize: await file.length(),
      title: title,
      artist: _nullIfEmpty(metadata.artist),
      album: _nullIfEmpty(metadata.album),
      trackNumber: metadata.trackNumber,
      discNumber: metadata.discNumber,
      durationMs: metadata.durationMs?.round(),
      year: metadata.year,
      genre: _nullIfEmpty(metadata.genre),
      bitrate: null,
      sampleRate: null,
      mimeType: mimeTypeForPath(filePath) ?? 'audio/unknown',
      pictureBytes: pictureBytes,
      pictureMimeType: pictureMimeType,
      hasEmbeddedArt: hasEmbeddedArt,
      lyricsFilePath: lyricsPath,
    );
  }

  /// Parses metadata for multiple files sequentially.
  ///
  /// [onProgress] is called after each file is parsed.
  Future<List<ScannedSong>> parseAll(
    List<String> filePaths, {
    void Function(int processed, int total, String currentFile)? onProgress,
  }) async {
    final results = <ScannedSong>[];
    final total = filePaths.length;

    for (var i = 0; i < total; i++) {
      final path = filePaths[i];
      try {
        final song = await parse(path);
        results.add(song);
      } catch (e) {
        // If parsing fails, still create a minimal entry with file info
        // and attempt to associate a .lrc file.
        final fileName = p.basename(path);
        final lyricsPath = _findLrcFile(path);
        results.add(
          ScannedSong(
            filePath: path,
            fileName: fileName,
            fileSize: await File(path).length(),
            title: p.basenameWithoutExtension(path),
            mimeType: mimeTypeForPath(path) ?? 'audio/unknown',
            lyricsFilePath: lyricsPath,
          ),
        );
      }
      onProgress?.call(i + 1, total, p.basename(path));
    }

    return results;
  }

  /// Looks for a `.lrc` file with the same base name as [audioPath].
  ///
  /// Returns the path if found, or `null` otherwise.
  String? _findLrcFile(String audioPath) {
    final dir = p.dirname(audioPath);
    final baseName = p.basenameWithoutExtension(audioPath);
    final lrcPath = p.join(dir, '$baseName.lrc');
    final lrcFile = File(lrcPath);
    if (lrcFile.existsSync()) {
      return lrcPath;
    }
    // Also check uppercase extension (some files use .LRC)
    final lrcUpperPath = p.join(dir, '$baseName.LRC');
    final lrcUpperFile = File(lrcUpperPath);
    if (lrcUpperFile.existsSync()) {
      return lrcUpperPath;
    }
    return null;
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
