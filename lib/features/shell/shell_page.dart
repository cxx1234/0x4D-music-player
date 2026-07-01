import 'package:flutter/material.dart';

import '../library/library_page.dart';
import '../player/player_page.dart';
import '../playlist/playlist_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';

enum NavigationItem {
  library('音乐库', Icons.library_music),
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
                  labelType: NavigationRailLabelType.all,
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

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 44,
                  height: 44,
                  color: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '未在播放',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '选择一首歌曲',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded),
                    onPressed: null,
                    tooltip: '上一首',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_filled_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    iconSize: 36,
                    onPressed: null,
                    tooltip: '播放',
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded),
                    onPressed: null,
                    tooltip: '下一首',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
