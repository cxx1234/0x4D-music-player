# 0x4D Music Player

A local music player built with **Flutter**.

<p align="center">
  <img src="assets/icon/0x4D_rounded_full.png" alt="App Icon" width="120">
  <br/>
  <img src="screenshots/0x4D_V0_2.png" alt="0x4D Music Player" width="720">
</p>

## Features

- **Local music library** — pick a folder, scan your files, and parse embedded metadata (title, artist, album artist, album, track, disc, duration, year, genre, bitrate, sample rate, cover art). A file watcher keeps the library in sync when files change; removing a folder also cleans up orphaned albums and artists.
- **Albums & Artists** — browse by grid, open dedicated detail pages (album pages group tracks by disc), and hit "play all".
- **Playlists** — create / rename / delete playlists, add songs from the library, drag to reorder, import / export **M3U8**, plus a built-in **Favorites** view.
- **In-page search** — live filtering with match counts across Library, Albums, Artists and Playlists.
- **Playback queue** — play next, reorder, repeat modes and shuffle, with the queue, repeat/shuffle state and playback position persisted across restarts.
- **Hi-Res audio** — playback via `just_audio`, including lossless formats like FLAC.
- **Lyrics** — synced `.lrc` lyrics on the Now Playing page, auto-detected next to the audio file, with bilingual (e.g. Chinese-Japanese) line splitting and adjustable text size.
- **System media controls** (macOS) — lock-screen / media-key controls (play, pause, next, previous, seek) with Now Playing metadata and cover art; dock menu and window restore after close.
- **Smart sorting** — pinyin and Japanese kana based sort keys for natural ordering in the library.
- **Cover art caching** — album art is extracted once and cached for fast browsing.
- **Volume & favorites** — persistent volume control and a favorites toggle on the player bar.
- **Logging & error handling** — leveled file logs with a built-in viewer, a startup error page, and graceful playback-error handling (auto-skip with a retry limit).

### Planned

- Multiple Display Language Support
- Gapless playback
- DSD support
- Windows / Linux system media controls

## Getting Started

### Prerequisites

- Flutter SDK (Dart `^3.12`) — see [flutter.dev](https://flutter.dev)
- macOS is currently the primary target (full media-control integration)

### Build & Run

```bash
flutter pub get
flutter run -d macos
```

## Project Structure

Feature-oriented layout — shared infrastructure in `core/`, business features in `features/`, reusable widgets in `widgets/`.

```
lib/
├── app/          # app configuration, routing, themes
├── core/         # audio, database, services, utils, constants
├── features/     # library, album, artist, playlist, player, settings, shell
├── models/       # application models
└── widgets/      # reusable UI components
```

See [docs/Architecture.md](docs/Architecture.md) for the full architecture and [docs/Rules.md](docs/Rules.md) for development conventions.

## Tech Stack

- **Flutter / Dart**
- **drift** — SQLite ORM for the local library database
- **just_audio** — audio playback
- **audio_metadata_reader** — metadata & embedded cover art parsing (pure Dart, fork version)
- **flutter_lyric** — `.lrc` lyric rendering
- **file_picker / watcher** — folder selection & library change watching
- **lpinyin** — pinyin sort keys

## Testing

```bash
flutter test
```

## License

[MIT](LICENSE) © 2026 Jerry C