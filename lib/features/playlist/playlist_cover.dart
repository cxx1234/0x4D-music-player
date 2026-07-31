import 'package:flutter/material.dart';

import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';

/// 播放列表封面：取前 4 首歌的封面拼成 2x2 网格；无歌/无封面时显示图标占位。
class PlaylistCover extends StatefulWidget {
  final int playlistId;
  final double size;
  final double borderRadius;

  /// 变化时触发封面重新加载（例如播放列表歌曲数变化后刷新封面）。
  final Object? revision;

  const PlaylistCover({
    super.key,
    required this.playlistId,
    this.size = 120,
    this.borderRadius = 12,
    this.revision,
  });

  @override
  State<PlaylistCover> createState() => _PlaylistCoverState();
}

class _PlaylistCoverState extends State<PlaylistCover> {
  List<String> _artPaths = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PlaylistCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.revision != widget.revision) {
      _load();
    }
  }

  Future<void> _load() async {
    final songs = await ServiceLocator.songRepo.getSongsInPlaylist(
      widget.playlistId,
      limit: 4,
    );
    if (!mounted) return;
    setState(() {
      _artPaths = songs
          .map((s) => s.albumArtFilePath)
          .where((p) => p != null)
          .cast<String>()
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget child;
    if (_artPaths.isEmpty) {
      // 新建的空播放列表：居中图标占位。
      // 用固定大小而非 widget.size 比例，避免父级传 double.infinity 时算出差值。
      child = Center(
        child: Icon(
          Icons.queue_music_rounded,
          size: 44,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else if (_artPaths.length == 1) {
      child = CachedAlbumArt(
        albumArtFilePath: _artPaths.first,
        hasEmbeddedArt: true,
        size: widget.size,
        borderRadius: widget.borderRadius,
      );
    } else {
      child = _buildGrid(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: child,
        ),
      ),
    );
  }

  Widget _buildGrid(ThemeData theme) {
    final cells = <Widget>[];
    for (var i = 0; i < 4; i++) {
      final path = i < _artPaths.length ? _artPaths[i] : null;
      cells.add(
        Expanded(
          child: path != null
              ? CachedAlbumArt(
                  albumArtFilePath: path,
                  hasEmbeddedArt: true,
                  size: double.infinity,
                  borderRadius: 0,
                )
              : Container(color: theme.colorScheme.surfaceContainerHighest),
        ),
      );
    }
    return Column(
      children: [
        Expanded(child: Row(children: [cells[0], cells[1]])),
        Expanded(child: Row(children: [cells[2], cells[3]])),
      ],
    );
  }
}
