import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';
import '../../widgets/detail_top_bar.dart';
import '../../widgets/play_all_button.dart';

/// "我的收藏"详情页：布局与播放列表详情一致（详情块 + 播放全部 + 列表），可取消喜欢。
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<Song> _songs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await ServiceLocator.songRepo.getFavoriteSongs();
    if (!mounted) return;
    setState(() {
      _songs = songs;
      _loading = false;
    });
  }

  Future<void> _unfavorite(Song song) async {
    await ServiceLocator.songRepo.toggleFavorite(song.id);
    await _load();
  }

  void _playAll() {
    if (_songs.isNotEmpty) {
      ServiceLocator.player.playFromList(_songs, startIndex: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final player = ServiceLocator.player;

    return Scaffold(
      appBar: const DetailTopBar(title: '我的收藏'),
      body: ListenableBuilder(
        listenable: player,
        builder: (context, _) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              // 详情块（底部 Material 阴影分隔列表区）
              Material(
                color: theme.colorScheme.surface,
                elevation: 3,
                child: _buildHeader(theme),
              ),
              if (_songs.isEmpty)
                _buildEmptyState(theme)
              else
                Expanded(
                  child: Material(
                    type: MaterialType.transparency,
                    clipBehavior: Clip.hardEdge,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                      itemCount: _songs.length,
                      itemBuilder: (context, index) {
                        final song = _songs[index];
                        final isCurrent = song.id == player.currentSong?.id;
                        return ListTile(
                          selected: isCurrent,
                          selectedTileColor: theme.colorScheme.primary
                              .withValues(alpha: 0.1),
                          leading: SizedBox(
                            width: 44,
                            height: 44,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedAlbumArt(
                                albumArtFilePath: song.albumArtFilePath,
                                hasEmbeddedArt: song.hasEmbeddedArt == 1,
                                size: 44,
                                borderRadius: 6,
                              ),
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isCurrent
                                  ? theme.colorScheme.primary
                                  : null,
                              fontWeight: isCurrent ? FontWeight.bold : null,
                            ),
                          ),
                          subtitle: song.artist != null
                              ? Text(
                                  song.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          trailing: PopupMenuButton<String>(
                            tooltip: '更多',
                            onSelected: (value) {
                              if (value == 'play') {
                                ServiceLocator.player.playFromList(
                                  _songs,
                                  startIndex: index,
                                );
                              } else if (value == 'unfavorite') {
                                _unfavorite(song);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(value: 'play', child: Text('播放')),
                              PopupMenuItem(
                                value: 'unfavorite',
                                child: Text('取消喜欢'),
                              ),
                            ],
                          ),
                          onTap: () => ServiceLocator.player.playFromList(
                            _songs,
                            startIndex: index,
                          ),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 140,
              height: 140,
              color: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.favorite,
                size: 56,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的收藏',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_songs.length} 首歌曲',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                // 椭圆形「播放全部」文本按钮，位于信息文本下方
                PlayAllButton(onPlayAll: _playAll),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('还没有收藏的歌曲', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              '在歌曲的"更多"菜单里点"喜欢"即可收藏',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
