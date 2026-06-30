import 'package:flutter/material.dart';

import '../library/library_page.dart';
import '../playlist/playlist_page.dart';
import '../search/search_page.dart';
import '../settings/settings_page.dart';

enum NavigationItem {
  library('音乐库', Icons.library_music, LibraryPage.new),
  playlists('播放列表', Icons.playlist_play, PlaylistPage.new),
  search('搜索', Icons.search, SearchPage.new),
  settings('设置', Icons.settings, SettingsPage.new);

  final String label;
  final IconData icon;
  final Widget Function() pageBuilder;

  const NavigationItem(this.label, this.icon, this.pageBuilder);
}

class ShellPage extends StatefulWidget {
  const ShellPage({super.key});

  @override
  State<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends State<ShellPage> {
  NavigationItem _selected = NavigationItem.library;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Row(
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
          Expanded(
            child: _selected.pageBuilder(),
          ),
        ],
      ),
    );
  }
}
