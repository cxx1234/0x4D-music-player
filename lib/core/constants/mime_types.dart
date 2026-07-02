/// Maps audio file extensions to MIME types.
const Map<String, String> extensionToMimeType = {
  '.mp3': 'audio/mpeg',
  '.flac': 'audio/flac',
  '.m4a': 'audio/mp4',
};

/// Returns the MIME type for the given file path, or null if unknown.
String? mimeTypeForPath(String path) {
  final ext = _extension(path).toLowerCase();
  return extensionToMimeType[ext];
}

String _extension(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1) return '';
  return path.substring(dot);
}
