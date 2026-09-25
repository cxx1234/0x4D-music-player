# 0x4D Architecture

## Project Vision

0x4D Music Player is a modern desktop music player built with Flutter.

### The project focuses on:

* Local music library
* Clean architecture
* Maintainable codebase
* Cross-platform support
* Hi-Res audio support
* Future DSD support

### The project does NOT currently target:

* Music streaming
* User accounts
* Cloud synchronization
* Social features

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
at a time**; queue sequencing, shuffle order, repeat modes and auto-skip live in
`PlayerService`. See `AudioEngine-Migration.md`.

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
  advances and **before** the repeat-one check, so "停在这一曲末尾" also works
  under 单曲循环. The engine reports `completionStream` even with
  `ReleaseMode.loop`; deciding whether that means "track finished" is
  `PlayerService`'s job, not the engine's.

The UI (`SleepTimerButton` in the player page's `PlayerBar`) and the notice
SnackBar (`app.dart`) only read `ServiceLocator.sleepTimer` state — they contain no
scheduling logic.

### Track-change notifications

`TrackNotificationService` (`lib/core/services/track_notification_service.dart`)
posts a desktop banner (macOS) whenever the current song changes. It listens to
`PlayerService.currentSongNotifier`, so every way of changing tracks — manual
skip, auto-advance, shuffle, repeat and jump-to-song — goes through one path; a
300 ms debounce collapses rapid skipping, and a fixed notification id makes each
new track **replace** the previous banner instead of stacking up in Notification
Center.

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
banner only refreshes on track changes.

Permission is requested when the user turns the switch on in Settings › Playback,
with the first track change as a fallback (the switch defaults to on).

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