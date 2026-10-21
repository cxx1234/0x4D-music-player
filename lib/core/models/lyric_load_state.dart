/// Lyrics loading state for the current track.
///
/// [loading] covers the window between the queue switching to a new song and
/// the player having that song loaded. The view shows a placeholder instead of
/// the previous song's lyrics or the empty state during this window.
enum LyricLoadState { idle, loading, ready, empty }
