import 'package:flutter/material.dart';

import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';

/// 全局常驻的迷你播放条（挂在根 Scaffold 的 bottomNavigationBar，跨所有页面可见）。
class NowPlayingBar extends StatelessWidget {
  final VoidCallback onTap;

  const NowPlayingBar({super.key, required this.onTap});

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
