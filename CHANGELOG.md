# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2026-07-31
### Added
- macOS system media controls (MPRemoteCommandCenter / MPNowPlayingInfoCenter, album art via file path)
- Playlists: browse / detail / favorites / add songs / drag-to-reorder / rename / delete
- Database schema v4: new `Playlists` / `PlaylistSongs` tables; sort keys (pinyin + Japanese kana) for albums / artists / songs
- Library uses shared `SongTile` and adds a sort menu (title / date added / play count / year)

### Fixed
- Remove `sqlite3_flutter_libs` to fix a startup crash caused by double-loading sqlite

## 2026-07-27
### Added
- Play queue UI with JSON persistence (queue restored on restart)
- Player architecture refactor: split into `PlayQueue` (data layer) and `PlayerService` (playback layer)
- Queue management: add / remove / play next / move / clear / jump
- Rebrand project identity and update copyright

## 2026-07-11
### Added
- Albums & Artists pages with album-art deduplication

## 2026-07-07
### Added
- Extract album art and associate `.lrc` lyric files during scan

## 2026-07-06
### Added
- Audio playback via `just_audio`

## 2026-07-02
### Added
- Audio file scanning, metadata parsing, and folder watching

## 2026-07-01
### Added
- SQLite database layer (drift) and settings service

## 2026-06-30
### Added
- Reorganized into feature-oriented architecture
- Folder picker and player navigation

## 2026-06-28
### Added
- Initial project setup
