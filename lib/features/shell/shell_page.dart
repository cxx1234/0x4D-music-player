import 'package:flutter/material.dart';

import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';
import '../album/album_page.dart';
import '../artist/artist_page.dart';
import '../library/library_page.dart';
import '../player/player_page.dart';
import '../playlist/playlist_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';

enum NavigationItem {
  library('音乐库', Icons.library_music),
  albums('专辑', Icons.album),
  artists('歌手', Icons.person),
  playlists('播放列表', Icons.playlist_play),
  search('搜索', Icons.search),
  settings('设置', Icons.settings);

  final String label;
  final IconData icon;

  const NavigationItem(this.label, this.icon);
}

class ShellPage extends StatefulWidget {
  final bool isInitialized;

  const ShellPage({super.key, this.isInitialized = false});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  NavigationItem _selected = NavigationItem.library;

  void _openPlayer() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PlayerPage()));
  }

  Widget _buildPage() {
    switch (_selected) {
      case NavigationItem.library:
        return LibraryPage(isInitialized: widget.isInitialized);
      case NavigationItem.albums:
        return const AlbumsPage();
      case NavigationItem.artists:
        return const ArtistsPage();
      case NavigationItem.playlists:
        return const PlaylistPage();
      case NavigationItem.search:
        return const SearchPage();
      case NavigationItem.settings:
        return const SettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selected.index,
                  onDestinationSelected: (index) {
                    setState(() => _selected = NavigationItem.values[index]);
                  },
                  labelType: NavigationRailLabelType.selected,
                  leading: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Icon(
                      Icons.music_note,
                      size: 32,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  destinations: [
                    for (final item in NavigationItem.values)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: _buildPage()),
              ],
            ),
          ),
          _NowPlayingBar(onTap: _openPlayer),
        ],
      ),
    );
  }
}

class _NowPlayingBar extends StatelessWidget {
  final VoidCallback onTap;

  const _NowPlayingBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!ServiceLocator.isReady) {
      return const SizedBox(height: 64);
    }

    final player = ServiceLocator.player;

    return ListenableBuilder(
      listenable: player,
      builder: (context, _) {
        final song = player.currentSong;

        return Material(
          color: theme.colorScheme.surfaceContainerLow,
          child: InkWell(
            onTap: song != null ? onTap : null,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Album art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: CachedAlbumArt(
                        albumArtFilePath: song?.albumArtFilePath,
                        hasEmbeddedArt: (song?.hasEmbeddedArt ?? 0) == 1,
                        size: 44,
                        borderRadius: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Song info
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song?.title ?? '未在播放',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          song?.artist ?? '选择一首歌曲',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Controls
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded),
                        onPressed: song != null
                            ? () => player.previous()
                            : null,
                        tooltip: '上一首',
                      ),
                      IconButton(
                        icon: Icon(
                          player.isPlaying
                              ? Icons.pause_circle_filled_rounded
                              : Icons.play_circle_filled_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        iconSize: 36,
                        onPressed: song != null
                            ? () => player.togglePlay()
                            : null,
                        tooltip: player.isPlaying ? '暂停' : '播放',
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: song != null ? () => player.next() : null,
                        tooltip: '下一首',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
