# 0x4D Architecture

## Project Vision

0x4D Music Player is a modern desktop music player built with Flutter.

### The project focuses on:

* Local music library
* Clean architecture
* Maintainable codebase
* Desktop cross-platform support (macOS today; Windows / Linux planned)
* Hi-Res audio support
* Future DSD support

### The project does NOT currently target:

* Music streaming
* User accounts
* Cloud synchronization
* Social features
* Mobile (iOS / Android) and web clients

The mobile and web targets were dropped in 0.4.x — the library model is built on
scanning arbitrary folders through the OS file picker (security-scoped bookmarks) and on
a desktop layout, neither of which maps onto Android scoped storage, the iOS document
picker or the browser. Their platform folders were template scaffolding only and have
been removed; `flutter create --platforms=<name> .` restores one on demand.

⸻

## Design Principles

The project should remain simple, modular and maintainable.

### Core principles:

* Separation of concerns
* Composition over inheritance
* Dependency inversion
* Feature-oriented structure
* Testable business logic

⸻

## Architecture

### Application layers:

UI

↓

ViewModel

↓

Repository

↓

Services

↓

Database / Audio Engine / File System

### Rules:

* UI never accesses the database directly.
* UI never interacts with audio libraries directly.
* Business logic belongs to Services or Repositories.
* Models remain immutable whenever possible.

### Data freshness (live queries)

Library data in the UI is reactive: browsing and detail pages subscribe to a drift
`watch*` query through `SongRepository` (`watchAvailableSongs`, `watchAllAlbums`,
`watchSongsByAlbum`, `watchSongsInPlaylist`, `watchFavoriteSongs`, …) instead of
re-querying on their own. Any write — folder-watcher batch, scan, playlist edit,
favourite toggle — is committed to SQLite, and drift re-emits the affected queries,
so pages no longer need "reload when the tab becomes active" hooks.

* `FolderWatcherService` is a **writer only**: it parses changed files and upserts
  them. It does not drive UI refresh.
* `PageViewModel.trackStream` owns the subscriptions and cancels them in `dispose`.
* Playback-queue pruning hangs off the library query emission (the queue is player
  state, not a database query).
* Custom SQL aggregates used by a live query must declare `readsFrom`, otherwise
  drift has no table dependency to invalidate them.

⸻

## Project Structure

```
lib/

app/
Application configuration, routing and themes.

core/
Shared infrastructure.

Contains:

* Audio
* Database
* Services
* Utilities
* Constants

features/
Business features.

Examples:

* Library
* Player
* Playlist
* Settings

models/
Application models.

widgets/
Reusable UI components.
```
⸻

## Audio Architecture

Playback should always go through AudioEngine.

Example:

UI

↓

PlayerViewModel

↓

PlaybackService

↓

AudioEngine

↓

Platform implementation

The UI must never directly call the audio library or any platform API.

Implemented as a single-track `AudioEngine` (`lib/core/audio/audio_engine.dart`,
with `AudioplayersEngine` as the only implementation). The engine plays **one file
at a time** and **never loops**; queue sequencing, shuffle order, repeat modes and
auto-skip live in `PlayerService`. See `AudioEngine-Migration.md`.

The engine contract carries two invariants that the rest of the app relies on:

* `completionStream` means "audio has stopped and the engine will not resume on
  its own". Repeat is implemented above it: on a completion in repeat-one,
  `PlayerService` seeks to zero and plays the same file again.
* `positionStream` must keep reporting while audio advances, and must come back
  after a `seek`/`play` that follows a completion.

Do not push looping back into an engine: `audioplayers`' native loop keeps the
audio going while leaving its Dart side in `completed` and stopping the position
updater, so progress, lyrics and the play button all freeze (see
`Pitfalls.md` C18).

### Sleep timer (session-only)

`SleepTimerService` (`lib/core/services/sleep_timer_service.dart`) owns both trigger
kinds and is **never persisted** (重启即失效):

* **duration** — its own tick; on expiry it calls
  `PlayerService.fadeOutAndPause()` (engine-level volume ramp, then pause — the
  user's `volume` / slider position are deliberately left untouched).
  If the `sleepTimerFinishCurrentTrack` setting is on **and playback is actually
  running**, expiry instead switches the mode to `endOfTrack` (\"等这一首播完再停\");
  the button then shows no countdown, it shows the waiting mode.
* **end of track / end of queue** — registers
  `PlayerService.onBeforeTrackAdvance`, which is consulted *before* the queue
  advances and **before** the repeat mode is applied, so "停在这一曲末尾" also
  works under 单曲循环. The hook sits before repeat precisely because repeat-one
  now restarts the track from the app layer; ordering it later would restart
  playback first.

The UI (`SleepTimerButton` in the player page's `PlayerBar`) and the notice
SnackBar (`app.dart`) only read `ServiceLocator.sleepTimer` state — they contain no
scheduling logic.

### Playback notifications

`TrackNotificationService` (`lib/core/services/track_notification_service.dart`)
posts desktop banners (macOS) for two events, both behind the same Settings ›
Playback switch:

- **Track change** — it listens to `PlayerService.currentSongNotifier`, so every
  way of changing tracks (manual skip, auto-advance, shuffle, repeat and
  jump-to-song) goes through one path.
- **Playback resume** — it listens to `PlayerService.playbackIntentNotifier`,
  which `play()` / `pause()` emit and nothing else does. The engine-facing
  `playingNotifier` would not do: it flips during load windows, automatic
  advances and queue end, so a banner would appear while the app changes tracks
  on its own. The intent signal is also the reason sleep-timer fade-out (which
  pauses through a private path) never reports.

Both use a 300 ms debounce (separate timers, so one never cancels the other) and
a shared fixed notification id, which makes each new banner **replace** the
previous one instead of stacking up in Notification Center.

Banners are **background-only**: `presentBanner` / `presentList` / `presentAlert`
are all off, which suppresses the banner while the app is in front (the player bar
and the player page already show the same thing) and leaves the windowless case —
the app keeps running after the window closes — as the one that gets a banner.
Clicking it restores the window and opens the player page.

The cover travels as a notification attachment, but **never as the cached file**:
macOS moves attachments that live outside the app bundle into its own store, so
passing `Documents/covers/*` would delete the app's own cover. The service copies
the cover to `Documents/notif_attachments` first — not to the sandbox temp
directory, which the system cannot read back.

A "Next" action is registered on the notification category (actions can only be
configured during `initialize`) and handled in `_onResponse`; it skips without
activating the app. Play/pause is deliberately absent: it is stateful, and the
banner still does not refresh when playback pauses, so the button would go stale
after a background pause.

Permission is requested when the user turns the switch on in Settings › Playback,
with the first banner as a fallback (the switch defaults to on).

⸻

## Data Flow

Music Folder

↓

Library Scanner

↓

Metadata Parser

↓

Database

↓

Repository

↓

ViewModel

↓

UI

⸻

## Core Models

Song

Represents one audio file.

Album

Represents one album.

Artist

Represents one artist.

Playlist

Represents an ordered collection of songs.

PlaybackQueue

Represents the current playing queue.

⸻

## MVP Scope

Version 0.1 includes:

* Import music folder
* Scan local library
* Parse metadata
* Store library in SQLite
* Display song list
* Basic playback
* Previous / Next
* Pause / Resume

Everything else belongs to future milestones.

⸻

## Future Goals

Future versions may include:

* Album artwork
* Lyrics
* Playlist management
* Gapless playback
* ReplayGain
* Hi-Res improvements
* DSD support
* Exclusive output mode
* Plugin architecture

⸻

## Dependency Policy

Prefer packages using:

* MIT
* BSD
* Apache 2.0

Avoid introducing GPL dependencies unless explicitly approved.

Keep third-party dependencies minimal.

⸻

## Documentation

Any architectural change should also update this document.

Architecture documentation is considered part of the source code.