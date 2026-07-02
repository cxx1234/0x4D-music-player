import 'dart:io';

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
  Future<ScannedSong> parse(String filePath) async {
    final file = File(filePath);
    final metadata = await MetadataGod.readMetadata(file: filePath);

    final fileName = p.basename(filePath);
    final title = (metadata.title?.trim().isNotEmpty == true)
        ? metadata.title!.trim()
        : p.basenameWithoutExtension(filePath);

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
        final fileName = p.basename(path);
        results.add(
          ScannedSong(
            filePath: path,
            fileName: fileName,
            fileSize: await File(path).length(),
            title: p.basenameWithoutExtension(path),
            mimeType: mimeTypeForPath(path) ?? 'audio/unknown',
          ),
        );
      }
      onProgress?.call(i + 1, total, p.basename(path));
    }

    return results;
  }

  String? _nullIfEmpty(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
