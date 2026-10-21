# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.7] - 2026-10-22

### Added
- The about page shows the app artwork instead of a generic note glyph. The
  artwork ships in two variants because one logo cannot serve both surfaces: a
  dark-glyph set disappears on the dark theme, and a white-glyph set disappears
  on the light one. The variant is picked from `Theme.brightness` at build time,
  so switching the theme swaps the image with no reload
- Right-click (secondary click) context menus on the desktop surfaces that carry
  a set of actions. Which menu opens is decided by the control, not by the right
  click, so the two agree: a row that already has a three-dot button opens *that*
  menu (same position, same animation — the button's own `showButtonMenu()`), so
  the five song-list call sites needed no change; row-shaped entries without a
  button (queue rows, artist rows, the "favourites" bar in the playlists page)
  use the standard popup menu anchored on the row's trailing slot, i.e. exactly
  where a three-dot button would be; grid cards (album, playlist) use the
  container-transform menu they already have for their three-dot and long press.
  Entries do not repeat what a plain click already does — a row click plays or
  opens, so the new menus hold only the *other* actions (queue rows get "remove
  from queue", artist rows get "play all", the album card gets "play all / add to
  queue"). Right-clicking is turned off while a list is in reorder or
  multi-select mode, since the row gestures there are already drag and check
- Lyrics follow playback through `flutter_lyric`'s frame-sampled
  `LyricProgressSource` instead of the ~200 ms position stream.
  `LyricsViewModel` binds a `PlayerLyricProgressSource` and drops its own
  `setPosition` calls, so word-level highlight and line motion update on every
  display frame; `PlayerService.isAdvancing` tells real playback apart from the
  load window so a stale position is never sampled as progress
- Word-timed QRC/YRC lyrics are no longer flattened into one static line. Any
  text the LRC bilingual splitter does not own is handed to
  `LyricDocument.parse`, which auto-detects the format; LRC keeps the existing
  main/translation split, and blank timestamp entries survive so interlude
  countdowns have something to anchor on
- Settings › Appearance › Lyrics display opens a dedicated page. On wide
  windows a live looped preview sits on the left and the controls scroll on the
  right; narrow windows keep the controls only. The preview runs its own
  controller and a ticker-driven progress source, and both it and the player
  build their `LyricPreset` from one shared function, so font/translation
  changes cannot look different from playback
- Lyrics text effects: Word Pop pops each sung character upward and holds it
  for the rest of the line. A two-step strength preset (默认 / 强) scales the
  lift only (3.5 / 5 px) and keeps a fixed 900 ms rise; plain
  LRC simulates word timing so the effect works without QRC/YRC data. The live
  preview and the player share the same preset
- Word highlight fill can be switched off independently of Word Pop. With it
  off, the character sweep disappears while the lift still works; with it on,
  plain LRC simulates word timing so the fill sweeps per character
- Line transitions are selectable: classic, a single soft scale-up-and-settle
  (no spring oscillation), slide or none. The choice goes through the same
  shared preset as the player and the live preview, so the page shows the real
  motion instead of a stand-in. Slide exposes a left/right alignment: the text
  anchors to that edge and enters from the same side. Slide mode uses a 44 px
  horizontal inset (default 20 + the 24 px inactive offset), so the
  permanently shifted inactive rows keep a readable 20 px margin instead of
  being clipped at the viewport edge
- Line motion: an optional "row wave" uses the Apple Music recipe (35 ms row
  stagger, 140 ms cap, 600 ms / 12 px wave, 64 px lag limit). It moves whole
  rows, independent of the per-character lift, and is off by default
- Distance blur is optional (off / light 2σ / standard 4σ, one extra offscreen
  blur layer per visible row) and stays crisp while browsing. Off by default;
  the settings row notes the per-row layer cost
- Countdown dots can now be switched off; the default stays on to match 4.1.
  Interludes still need a blank timestamp in plain LRC, and the row says so
- The playing page's lyric toolbar has a settings button next to translation
  and text size. It opens the same Lyrics display page; returning re-syncs the
  player's UI state and applies the changes immediately

### Changed
- Settings › Appearance now lists theme mode and accent colour before the
  lyrics display entry and the bar-fill switch, so the theme controls come
  first
- Lyric text size tiers are one step larger: 小 / 中 / 大 now map to
  1.0 / 1.25 / 1.5, and the old 大 is the new default 中
- Seeking while paused notifies the player's listeners explicitly, so
  frame-sampled consumers such as lyrics show the new position immediately
  instead of waiting for playback to resume
- The grid-card menus (album card, playlist card — three-dot, long press and
  right click alike) grow open in 240ms instead of 320ms and close in 180ms
  instead of 220ms. "The card unfolds into its options" does not need to take
  that long; at 320ms it read as slow next to the plain popup menus. The scope is
  `showCardMenu`, so the sleep-timer menu, which also uses the container
  transform, keeps the default timing it was tuned with
- Popup menus across the app ease out (`Curves.easeOutCubic`) instead of moving
  linearly. The framework's choreography spends the last third of its 300ms on
  the last few percent of the animated value, so a linear curve made the panel
  look settled while items were still trickling in. Keeping the framework's
  300ms, the last item now arrives at roughly 156ms instead of 267ms
- The sleep-timer menu grows out of its button instead of sliding up from the
  window edge. `PopupMenuRoute` recomputes its position every frame from the
  *current* panel size, so a menu taller than the space below the button gets
  its bottom edge pinned to the window and slides up from below — which the
  player-bar button at the very bottom of the window always hits. Position,
  size, corner radius and colour are now interpolated from the button, and the
  panel is positioned once and revealed by its own clip
- The playlist card menu grows up from the card's bottom edge instead of
  morphing from the whole card. The card (≈229 tall) and the panel (208 tall)
  are nearly the same size, so morphing from the card read as a shrink — the
  only visible movement was the bottom edge coming up. Starting from a 12px
  strip pinned to the card's bottom edge reads as filling upward, and leaves the
  top of the card (its cover) visible. The three-dot button and the long press
  share it, anchored on the card, and the panel is exactly as wide as the card;
  its row layout and size rules live in a shared `morph_menu.dart`, which the
  sleep timer uses as well
- Check slots in the morph menus are per row now. Entries that cannot be checked
  start at the panel padding instead of being indented for a check mark they
  would never show, so the sleep timer's preset rows and its "cancel" row no
  longer shift when a mode gets selected — and the playlist card, which has
  nothing checkable, has no dead space left of its labels. Panel width is
  measured per group (plain rows vs checkable rows), so the indent cannot push a
  long label into an ellipsis
- The in-app sleep-timer menu offers five presets (15/30/45/60/90) instead of
  seven. Its panel has a fixed height, and seven presets plus an active "cancel"
  row came to 512px — taller than the smallest window allows, so it had to
  scroll. The macOS menu-bar entry keeps 5/10, since a menu has no height limit

### Fixed
- The mini player bar now stays hidden for the whole player route stack.
  Opening Lyrics display above the player used to make the bar reappear, and
  tapping it pushed another player page; visibility now tracks whether any
  `PlayerPage` remains in the stack instead of only looking at the top route
- Morph menus that grow upward no longer slide under the traffic lights. The
  geometry kept only an 8px margin from the top of the window, but on macOS the
  titlebar is transparent and the Flutter view spans the whole window, so those
  first 52px are exactly where the traffic lights are drawn. Any panel that did
  not fit above its anchor had its top edge clamped to y=8 — the sleep-timer
  menu did it as soon as a timer was active. The top edge now stops below
  `layoutConfig.menuTopInset` (52 on macOS, 0 elsewhere) and the panel scrolls
  internally instead
- Pausing right after picking a song no longer leaves audio playing while the UI,
  the menu title and the macOS Now Playing rate all say "paused". The load window
  (`setSourceDeviceFile` + `getDuration`) is a real await, so the resume after it
  now re-checks the play intent instead of starting unconditionally
- The sleep timer can be cancelled during its five-second fade-out. The state used
  to be cleared the moment the countdown hit zero and only then begin fading, so
  the "cancel" entry vanished from both the player-bar menu and the native menu,
  and a play request in that window was undone by the fade-out's own trailing
  pause. The state now stays active behind a `fading` flag until the fade really
  ends, cancelling restores the volume immediately, and a new play request aborts
  the fade instead of fighting it
- The sleep-timer countdown measures against a deadline instead of subtracting one
  tick per tick, so a throttled timer or a sleeping machine no longer stretches
  "30 minutes" into an arbitrary wait. The "paused" notice is also posted only
  once playback actually stopped, not the moment the fade begins
- Media keys survive a native registration failure: `MediaControlService.setup` is
  wrapped in a try/catch like the menu and notification channels, so a startup
  race reports "media keys unavailable" instead of ending on the error page
- A failed menu-state push no longer caches its snapshot, so enabling, titles and
  checkmarks are retried on the next push instead of silently staying at the
  native defaults
- Notification album-art copies are reused when the source has not changed, and
  copies older than a week are cleaned up with the next copy. The throwaway copies
  directory used to grow with the library and re-copied whole covers on every
  track change
- Restoring the window from a notification that fails now logs a warning instead
  of swallowing the error, and the "stop" HUD reads "已停止 · 保留队列" to match
  what `stopPlayback` does (queue and current track kept)
- The sleep-timer menu no longer overflows on its cancel row. The container
  transform has to know the panel size before it opens, so the width was fixed
  at 228px, which a 90-minute timer ("取消定时（1:30:00）") is too wide for. The
  width is now measured from the widest row with the text scaler applied and
  clamped. The player-bar button label gets the same treatment: in the
  end-of-queue mode it reads "播完当前播放列表", the widest thing that 128px slot
  ever shows. Both now ellipsize instead of overflowing

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
- Keyboard focus no longer traps the app once `Tab` has moved it. Flutter disables
  its own Escape handling on a plain page route, and a mouse click never moves nor
  drops the focus, so the focus ring stayed on screen and `Space` kept activating
  that (sometimes invisible) button. `Escape` now drops the keyboard focus, and so
  does clicking empty space. The Escape handler is registered as a late key handler,
  which only runs when nothing else wanted the key, so dialogs, popup menus and the
  search field keep their own Escape behaviour
- `Space` is no longer swallowed by the native play/pause item while a widget holds
  the keyboard focus: the menu state now reports "a widget is focused" and that item
  steps aside, so `Space` activates the focused widget exactly like `Enter` does.
  With nothing focused `Space` is still play/pause. While a widget holds focus the
  item is greyed out, same as it already was during text editing
- The `⌘.` stop shortcut no longer triggers on `⌘⇧.` / `⌘⌥.`, and it no longer
  reports a stop when nothing is playing: the fallback now respects the same
  "there is a track" gate as the menu item
- The menu state no longer walks the widget tree on every ~200ms playback tick: the
  "is text editing" / "is a widget focused" answers are computed once when the focus
  changes and cached
- Startup no longer force-casts the window's content view controller. A change in the
  window structure there would have crashed during launch, before the Flutter startup
  error page could appear; the app now comes up without the native menu / sandbox
  channels instead and says so on the console
- Scanning no longer leaves background workers behind when a metadata batch has to
  abort part-way (for example when a worker fails to start): the worker handles are
  now kept and shut down as soon as the batch finishes or throws

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
