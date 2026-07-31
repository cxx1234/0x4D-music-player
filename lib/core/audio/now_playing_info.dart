/// Metadata describing the currently playing media, pushed to the platform's
/// system media controls (e.g. macOS Now Playing / Control Center / lock
/// screen).
class NowPlayingInfo {
  /// Song title.
  final String title;

  /// Artist name, if known.
  final String? artist;

  /// Album name, if known.
  final String? album;

  /// Total duration of the current song.
  final Duration? duration;

  /// Current playback position.
  final Duration? position;

  /// Whether playback is currently active.
  final bool isPlaying;

  /// Absolute path to a local cached album-art image (e.g.
  /// `{docDir}/covers/{hash}.jpg`), or `null` if no cover is available.
  ///
  /// Passing a file path instead of raw bytes keeps the platform-channel
  /// payload small.
  final String? coverFilePath;

  const NowPlayingInfo({
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.position,
    this.isPlaying = false,
    this.coverFilePath,
  });
}
