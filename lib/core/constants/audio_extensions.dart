/// Supported audio file extensions.
const Set<String> supportedAudioExtensions = {
  '.mp3',
  '.flac',
  '.m4a',
};

/// Whether the given file path has a supported audio extension.
bool isSupportedAudioExtension(String path) {
  final ext = path.toLowerCase();
  return supportedAudioExtensions.any((e) => ext.endsWith(e));
}
