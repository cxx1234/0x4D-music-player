# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-17
### Changed
- Player page redesign: unified `SongInfoCard` and full-width bottom `PlayerBar` (progress + controls + volume slider); wide-mode breakpoint 760 → 1000

## [0.1.0] - 2026-08-16
### Added
- Keep shell tabs alive (state / scroll / search preserved per tab)
- Deduplicate player notifications (`currentSongNotifier` / `playingNotifier`)
### Changed
- Persist player UI state; fix queue locate & theme issues
### Fixed
- Fix scan-to-DB sync, cover art, and scan efficiency
- Return to first song when the queue ends without auto-playing
- Unbind song-info width from album cover

## [0.1.0] - 2026-08-15
### Added
- Revamp now-playing page for wide & narrow modes
- Persist album year; polish list spacing and menus
- Scan-completion logging and hardened file logger
### Fixed
- Skip file logging in debug mode

## [0.1.0] - 2026-08-14
### Fixed
- Clean up orphaned albums / artists when removing a music folder

## [0.1.0] - 2026-08-13
### Added
- In-page search on feature pages (library / albums / artists / playlists)
- Persist playback state and resume position across restarts
### Changed
- Upgrade to `just_audio` 0.10.6 and migrate to its new playlist API
### Fixed
- Keep search collapse timer alive under frequent parent rebuilds

## [0.1.0] - 2026-08-11
### Added
- Structured error handling, logging, and log viewer page
### Fixed
- Crash when long-pressing a playlist card

## [0.1.0] - 2026-08-10
### Added
- macOS unified toolbar with natively centered traffic lights (green button = zoom/maximize)
### Changed
- Extract shared list components (`SongTile` / `CoverCard` / `DetailHeader`) and unify row layouts

## [0.1.0] - 2026-08-09
### Added
- macOS: restore main window after closing to background (Dock menu / reopen)
### Fixed
- Sync playback state with `just_audio` engine

## [0.1.0] - 2026-08-05
### Changed
- macOS traffic-light page avoidance & unified top bars (page toolbars / detail top bar)
### Fixed
- Prevent duplicate `PlayerService` listener registration

## [0.1.0] - 2026-08-03
### Added
- Global mini-player bar; player expands from bottom; queue auto-scroll
- Group multi-disc album tracks by disc
- Merge same-named albums from multi-artist songs
- M3U8 import / export
- Keep playback queue in sync with library changes (prune on removal / missing files)
### Fixed
- Restore macOS sandbox access at startup and surface failures (re-authorize banner)
- Auto-load library once `ServiceLocator` is ready

## [0.1.0] - 2026-08-02
### Added
- Responsive adaptive grid and ink-clipped scrollables
### Fixed
- Lazy-load audio sequence to fix playback after restart; make cached play queue usable after restart

## [0.0.1] - 2026-07-31
### Added
- macOS system media controls (MPRemoteCommandCenter / MPNowPlayingInfoCenter, album art via file path)
- Playlists: browse / detail / favorites / add songs / drag-to-reorder / rename / delete
- Database schema v4: new `Playlists` / `PlaylistSongs` tables; sort keys (pinyin + Japanese kana) for albums / artists / songs
- Library uses shared `SongTile` and adds a sort menu (title / date added / play count / year)

### Fixed
- Remove `sqlite3_flutter_libs` to fix a startup crash caused by double-loading sqlite

## [0.0.1] - 2026-07-27
### Added
- Play queue UI with JSON persistence (queue restored on restart)
- Player architecture refactor: split into `PlayQueue` (data layer) and `PlayerService` (playback layer)
- Queue management: add / remove / play next / move / clear / jump
- Rebrand project identity and update copyright

## [0.0.1] - 2026-07-11
### Added
- Albums & Artists pages with album-art deduplication

## [0.0.1] - 2026-07-07
### Added
- Extract album art and associate `.lrc` lyric files during scan

## [0.0.1] - 2026-07-06
### Added
- Audio playback via `just_audio`

## [0.0.1] - 2026-07-02
### Added
- Audio file scanning, metadata parsing, and folder watching

## [0.0.1] - 2026-07-01
### Added
- SQLite database layer (drift) and settings service

## [0.0.1] - 2026-06-30
### Added
- Reorganized into feature-oriented architecture
- Folder picker and player navigation

## [0.0.1] - 2026-06-28
### Added
- Initial project setup
