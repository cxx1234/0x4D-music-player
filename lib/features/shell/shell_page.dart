import 'package:flutter/material.dart';

import '../../core/constants/layout.dart';
import '../album/album_page.dart';
import '../artist/artist_page.dart';
import '../library/library_page.dart';
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
      body: Row(
        children: [
          // 左侧边栏顶部预留 layoutConfig.sidebarTopInset（macOS=56）给红绿灯悬浮，
          // 该值与原生层定位一致（红绿灯垂直居中于该区域）。
          Padding(
            padding: EdgeInsets.only(top: layoutConfig.sidebarTopInset),
            child: SizedBox(
              width: layoutConfig.sidebarWidth,
              child: NavigationRail(
                selectedIndex: _selected.index,
                onDestinationSelected: (index) {
                  setState(() => _selected = NavigationItem.values[index]);
                },
                labelType: NavigationRailLabelType.selected,
                leading: Padding(
                  // 上 10 / 下 15：让音乐图标与下方导航按钮拉开距离。
                  padding: const EdgeInsets.only(top: 10, bottom: 15),
                  child: Icon(
                    Icons.music_note,
                    size: 32,
                    color: theme.colorScheme.primary,
                  ),
                ),
                destinations: [
                  for (final item in NavigationItem.values)
                    NavigationRailDestination(
                      icon: Icon(item.icon, size: 26),
                      label: Text(item.label),
                    ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }
}
