/// Events sent from the platform's system media controls back into the app —
/// e.g. when the user presses a media key, uses the Touch Bar, or interacts
/// with the Control Center / lock screen.
sealed class MediaControlEvent {
  const MediaControlEvent();
}

/// User requested to start/resume playback.
class PlayEvent extends MediaControlEvent {
  const PlayEvent();
}

/// User requested to pause playback.
class PauseEvent extends MediaControlEvent {
  const PauseEvent();
}

/// User requested to toggle play/pause (single media key press).
class TogglePlayEvent extends MediaControlEvent {
  const TogglePlayEvent();
}

/// User requested the next track.
class NextEvent extends MediaControlEvent {
  const NextEvent();
}

/// User requested the previous track.
class PreviousEvent extends MediaControlEvent {
  const PreviousEvent();
}

/// User scrubbed the system seek bar to [position].
class SeekEvent extends MediaControlEvent {
  final Duration position;

  const SeekEvent(this.position);
}
