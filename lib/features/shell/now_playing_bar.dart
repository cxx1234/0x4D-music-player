import 'package:flutter/material.dart';

import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';

/// 全局常驻的迷你播放条（挂在根 Scaffold 的 bottomNavigationBar，跨所有页面可见）。
///
/// 订阅策略（性能）：内容层（封面/文本/按钮）只订阅低频通知
/// （切歌 `currentSongNotifier` + 播放态 `playingNotifier`），不随播放进度
/// 每 ~200ms 重建；「按播放进度填充」的背景进度层单独订阅 PlayerService 的
/// 高频通知（见 [_PlaybackFill]），刷新只重绘该层。
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

    // 外层 RepaintBoundary：整条底栏自成一合成层，内部刷新不波及页面；
    // 内容层只订低频通知器，播放进度 tick 不会重建封面/文本/按钮。
    return RepaintBoundary(
      child: ListenableBuilder(
        listenable: Listenable.merge([
          player.currentSongNotifier,
          player.playingNotifier,
        ]),
        builder: (context, _) {
          final song = player.currentSong;

          return Material(
            color: theme.colorScheme.surfaceContainerLow,
            child: InkWell(
              onTap: song != null ? onTap : null,
              child: SizedBox(
                height: 64,
                child: Stack(
                  children: [
                    // 进度背景填充层：从左到右按播放进度对背景着色。
                    // 独立成层 + RepaintBoundary：播放进度每 ~200ms 只重绘它，
                    // 不与内容层互相牵连。
                    const Positioned.fill(
                      child: RepaintBoundary(child: _PlaybackFill()),
                    ),
                    Padding(
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
                                hasEmbeddedArt:
                                    (song?.hasEmbeddedArt ?? 0) == 1,
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
                                onPressed: song != null
                                    ? () => player.next()
                                    : null,
                                tooltip: '下一首',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 底栏进度背景填充层：从左到右按播放进度对背景着色。
///
/// 单独订阅 PlayerService 的高频 position 通知（约每 200ms 一帧），配合外层
/// [RepaintBoundary] 隔离，使填充刷新只重绘本层，不重建/重绘封面、文本、
/// 按钮等内容。
///
/// 行为：
/// - 无当前歌曲 / 时长未知 / 进度为 0 时不绘制（保持空白）；
/// - 播放中随 position 推进，暂停时停留在当前填充宽度；
/// - 切歌后随 position/duration 变化自然回到 0 重新填充。
class _PlaybackFill extends StatelessWidget {
  const _PlaybackFill();

  @override
  Widget build(BuildContext context) {
    final settings = ServiceLocator.settings;
    // LayoutBuilder 放外层：widthFactor 变化只调整自身宽度，无需重建布局。
    return LayoutBuilder(
      builder: (context, constraints) {
        // 开关在设置页「外观」：关闭时直接不绘制、也不再订阅播放进度
        // （ValueListenableBuilder 之下不会挂高频监听，零开销）。
        return ValueListenableBuilder<bool>(
          valueListenable: settings.nowPlayingBarFillNotifier,
          builder: (context, enabled, _) {
            if (!enabled) return const SizedBox.shrink();
            final fillColor = Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.10);
            return ListenableBuilder(
              listenable: ServiceLocator.player,
              builder: (context, _) {
                final player = ServiceLocator.player;
                final durMs = player.duration.inMilliseconds;
                if (durMs <= 0) return const SizedBox.shrink();
                final fraction = (player.position.inMilliseconds / durMs)
                    .clamp(0.0, 1.0)
                    .toDouble();
                if (fraction <= 0) return const SizedBox.shrink();
                return Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    heightFactor: 1,
                    child: ColoredBox(color: fillColor),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
