# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.6] - 2026-09-21

### Added
- Track-change notifications: with the window closed or the app in the
  background, a new track posts a desktop banner with its album art, the title
  and "artist · album". Nothing is posted while the app is in front - the player
  bar and the player page already show what is playing there
- The banner carries a "Next" action that skips the track in the background
  without bringing the window forward; the notification for the new track then
  replaces it in place. Clicking the banner restores the window and opens the
  player page, including when the window had been closed
- Settings → Playback: "show a system notification when the track changes", on
  by default. Switching it on asks for the notification permission right away,
  and when that is denied a hint offers a shortcut to the system settings

### Fixed
- Track notifications no longer consume the album-art cache. macOS moves any
  attachment that is not inside the app bundle into its own store, and the covers
  live in the app container, so passing a cached cover straight to the plugin
  deleted it from under the app. The notification now gets a throwaway copy under
  `Documents/notif_attachments`, and the sandbox temp directory is avoided
  because the system cannot read files back out of it
- Settings → Appearance drew the leading icons of the "theme mode" and "accent
  color" rows in the plain black/white fallback of `ThemeData.iconTheme`: those
  two rows are hand-built instead of a `ListTile` (one carries the segmented
  button, the other the inline swatch strip), so they never received the
  `onSurfaceVariant` tint every neighbouring row inherits and read almost black
  in the light theme and one shade too bright in the dark one. Both now match
  the leading icons above and below them

## [0.2.5] - 2026-09-20

### Added
- Sleep timer, reachable from the timer button on the left of the player bar and
  from the macOS Playback menu: 5/10/15/30/45/60/90 minutes, "end of current
  track", "end of playlist" and cancel. The remaining time sits next to the icon;
  the timer is session-only and is not persisted across restarts
- Sleep timer expiry fades the volume out over 5s and then pauses, so playback
  stops mid-track without a click. The fade runs at engine level, so the volume
  slider and the persisted volume never move; any new playback aborts it
- Settings → Playback: a switch for "finish the current track first". With it on,
  a countdown that expires while something is playing waits for that track to end
  instead of stopping right away (it still stops immediately when paused)
- macOS Help menu: "About This App" opens the in-app Settings → About page; the
  standard system About panel stays in the App menu

### Changed
- The audio engine reports `onPlayerComplete` even while single-repeat is on, and
  deciding whether that means "the track finished" is `PlayerService`'s job again.
  That is what lets "end of current track" work with repeat-one enabled
- Sleep-timer actions from the menu bar go through `PlaybackFeedbackService` like
  the other external actions: they report through the HUD on every page except
  the player page, where the button itself changes state

### Fixed
- Sleep-timer button: the hover highlight is a circle (a pill once the countdown
  appears) instead of a square - child-mode `PopupMenuButton` wraps its child in
  a bare `InkWell`, which needs an explicit `borderRadius`

## [0.2.4] - 2026-09-18

### Added
- Feedback for actions that have no visible control: volume, track skips, play/pause
  and stop coming from the macOS menu or the media keys now report what happened. The
  HUD sits bottom-centre, above the SnackBar, for 1.2s, and repeated presses update it
  in place instead of queueing up
- Control pulse: those same shortcuts light up the matching button on the player page
  and in the now-playing bar for 180ms, so the controls mirror the action

### Changed
- Menu and media-control actions now go through one `PlaybackFeedbackService`, so both
  entry points share the same copy; at the end of the queue the HUD says "已是最后一首"
  (and "已是第一首" when going back) instead of silently doing nothing
- The HUD stays off on the player page: the volume slider, info card and controls
  already show that state there

### Fixed
- Song lists: the "now playing" highlight is now identical in every list. Only the library
  passed `isPlaying`, so the dimmed cover with the equalizer appeared there alone while the
  other lists kept the corner note badge and a pause glyph even while playing; and none of
  them rebuilt on play/pause because they subscribed to track changes alone
- Song lists: a stray `isPlaying` can no longer light up a row that is not the current track
- Artist detail: song list padding brought in line with the other lists (was 24/0/8/16), so the
  selected-row highlight is no longer a different width there
- Song rows: the play-state icon sits 12px from the duration text instead of 8, which read as
  one blob
- Volume: changes made with the menu shortcuts now surface the new value for 1.2s, the same
  way dragging the slider does (a held key restarts that timer instead of flickering)

## [0.2.3] - 2026-09-17

### Added
- Settings: "clear cache" now really deletes unreferenced cover files and reports how
  many were removed (previously a placeholder)

### Changed
- Replace `just_audio` with `audioplayers`, behind a new single-track `AudioEngine`
  abstraction: queue sequencing, shuffle order, repeat modes and auto-skip now live
  in `PlayerService` (no engine-side queue mirror)
- Pin `audio_metadata_reader` to the commit hash of the `feat/album-artist` fork
  instead of the branch name, so builds are reproducible
- macOS menu channel renamed from `flutter_music/menu` to `com.jerryc.txvziwm/menu`
- Remove the dead `setTopBarHeight` bridge (Dart call + Swift handler stub): traffic
  lights have been positioned natively by the unified toolbar since 2026-08-10

### Fixed
- List rows without ID3 tags (no artist/album) no longer sit 8px too high: `SongTile`
  and `ListItemTile` pin `ListTile.minTileHeight` to the 72 row extent used by the
  surrounding lists, instead of letting ListTile center the content in its default
  56-tall single-line box
- Player: a failed track no longer auto-skips twice (one underlying failure is reported
  through two channels by the engine), and the skip chain now keeps playing after
  reaching a playable file
- Player page: queue scroll offset is only restored when it belongs to the current
  queue; auto-scroll waits until the list has content dimensions
- Lyrics: two-pass bilingual split no longer mis-splits lines that only repeat a single
  distinct timestamp
- Library: favorite state in list menus stays in sync with the player
- Settings: writes are serialized and atomic (temp file + rename); a corrupt settings
  file is renamed to `.corrupt` and replaced with defaults instead of bricking startup
- Settings page: reload the cached-size row when the tab becomes visible again
- Watcher: events emitted while suspended no longer re-upsert files deleted meanwhile
- Scan: root-scoped purge no longer marks files outside the scanned root as missing;
  the `LIKE` pre-filter no longer treats `_` / `%` in paths as wildcards
- Playback: generation-guarded track loads so a stale load cannot overwrite the
  current one
- Media controls: per-second elapsed updates fall back to a full metadata push when
  the native side does not support them
- Player: seek slider keeps its preview position while dragging and only seeks on
  release; the now-playing bar rebuilds only on track/state changes

## [0.2.2] - 2026-09-08

### Added
- Accent color presets, including a follow-system option, and deeper monochrome grey
  layering
- Song menus: "Play Next" and "Add to Queue"; the "more" menu is built at open time
- Queue: auto-locate the currently playing track when the queue page opens
- Settings: "force rescan" action for the music library
- Lyrics: multi-timestamp lines with time-based two-pass bilingual matching
- Playlist detail: sort songs by pinyin sort key; "Play all" is disabled when the list
  is empty, and the Favorites entry stays visible when there are no playlists
- Settings / About: read the app version from `pubspec.yaml` via `package_info_plus`

### Changed
- Promote `LyricsViewModel` to a `ServiceLocator`-resident service
- Wait for data before running playlist export / import actions
- Drop queue actions from the now-playing card menu and rename the play-next label

### Fixed
- Scan: purge gone ghosts on force scan and scope a rescan to the scanned roots
- Folder watcher: debounce batch events, suspend during scans, refresh live
- Detail queries: exclude unavailable songs from artist / album detail
- Startup: initialize the binding inside `runZonedGuarded` to avoid a zone mismatch
  warning

## [0.2.0] - 2026-09-03

### Added
- macOS native menu bar (localized, with playback & file actions), blocking the
  titlebar double-click zoom over detail top bar buttons
- Now-playing bar playback progress fill, with a switch under Settings → Appearance

### Changed
- Cache per-page search / filter results (`QueryFilterCache`) instead of re-filtering
  on every rebuild
- Artist detail: fetch albums by id set instead of loading the whole album table
- Add `RepaintBoundary` around lyrics, the playing card and cover grids; narrow widget
  subscriptions so playback ticks no longer rebuild whole pages

### Fixed
- macOS: `Cmd+.` stops playback via keyCode + menu delegation, `Esc` exits search

## [0.1.0] - 2026-08-02

### Added
- In-page search on feature pages (library / albums / artists / playlists)
- Persist playback state and resume position across restarts
- Keep shell tabs alive (state / scroll / search preserved per tab)
- Deduplicate player notifications (`currentSongNotifier` / `playingNotifier`)
- Revamp now-playing page for wide & narrow modes
- Persist album year; polish list spacing and menus
- Scan-completion logging and hardened file logger
- Structured error handling, logging, and log viewer page
- Lyrics rendering via `flutter_lyric`, with bilingual translation and adjustable text size
- Complete settings page (theme, resume, cover cache, about)
- macOS unified toolbar with natively centered traffic lights (green button = zoom/maximize)
- macOS: restore main window after closing to background (Dock menu / reopen)
- Global mini-player bar; player expands from bottom; queue auto-scroll
- Group multi-disc album tracks by disc
- Merge same-named albums from multi-artist songs
- M3U8 import / export
- Keep playback queue in sync with library changes (prune on removal / missing files)
- Responsive adaptive grid and ink-clipped scrollables

### Changed
- Upgrade to `just_audio` 0.10.6 and migrate to its new playlist API
- Migrate to `file_picker` 12 and refresh the dependency set
- Extract shared list components (`SongTile` / `CoverCard` / `DetailHeader`) and unify row layouts
- macOS traffic-light page avoidance & unified top bars (page toolbars / detail top bar)
- Player page redesign: unified `SongInfoCard` and full-width bottom `PlayerBar` (progress + controls + volume slider); wide-mode breakpoint 760 → 1000
- Replace `Card` elevation shadows with a cheap 3-line drop shadow (`CardSurface`, `blurRadius: 0`) to avoid Impeller SDF shadow raster cost on weak GPUs (esp. Intel macOS)
- Persist player UI state; fix queue locate & theme issues

### Fixed
- Keep search collapse timer alive under frequent parent rebuilds
- Crash when long-pressing a playlist card
- Sync playback state with `just_audio` engine
- Prevent duplicate `PlayerService` listener registration
- Restore macOS sandbox access at startup and surface failures (re-authorize banner)
- Auto-load library once `ServiceLocator` is ready
- Lazy-load audio sequence to fix playback after restart; make cached play queue usable after restart
- Clean up orphaned albums / artists when removing a music folder
- Skip file logging in debug mode
- Fix scan-to-DB sync, cover art, and scan efficiency
- Return to first song when the queue ends without auto-playing
- Unbind song-info width from album cover

## [0.0.1] - 2026-06-28

### Added
- macOS system media controls (MPRemoteCommandCenter / MPNowPlayingInfoCenter, album art via file path)
- Playlists: browse / detail / favorites / add songs / drag-to-reorder / rename / delete
- Database schema v4: new `Playlists` / `PlaylistSongs` tables; sort keys (pinyin + Japanese kana) for albums / artists / songs
- Library uses shared `SongTile` and adds a sort menu (title / date added / play count / year)
- Play queue UI with JSON persistence (queue restored on restart)
- Player architecture refactor: split into `PlayQueue` (data layer) and `PlayerService` (playback layer)
- Queue management: add / remove / play next / move / clear / jump
- Rebrand project identity and update copyright
- Albums & Artists pages with album-art deduplication
- Extract album art and associate `.lrc` lyric files during scan
- Audio playback via `just_audio`
- Audio file scanning, metadata parsing, and folder watching
- SQLite database layer (drift) and settings service
- Reorganize into a feature-oriented architecture; folder picker and player navigation
- Initial project setup

### Fixed
- Remove `sqlite3_flutter_libs` to fix a startup crash caused by double-loading sqlite
