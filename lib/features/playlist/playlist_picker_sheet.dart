import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../l10n/l10n.dart';

/// 展示"选择播放列表"底部弹层，将 [songs] 加入选中的播放列表。
/// 含"新建播放列表…"入口。返回是否成功加入。
Future<bool> showPlaylistPicker(BuildContext context, List<Song> songs) async {
  final playlists = await ServiceLocator.songRepo.getAllPlaylists();
  if (!context.mounted) return false;

  final selectedId = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => _PlaylistPickerSheet(playlists: playlists),
  );
  if (selectedId == null) return false;

  await ServiceLocator.songRepo.addSongsToPlaylist(
    selectedId,
    songs.map((s) => s.id).toList(),
  );
  return true;
}

class _PlaylistPickerSheet extends StatefulWidget {
  final List<Playlist> playlists;

  const _PlaylistPickerSheet({required this.playlists});

  @override
  State<_PlaylistPickerSheet> createState() => _PlaylistPickerSheetState();
}

class _PlaylistPickerSheetState extends State<_PlaylistPickerSheet> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playlists = widget.playlists;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              context.l10n.playlistAddTo,
              style: theme.textTheme.titleMedium,
            ),
          ),
          if (playlists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.playlistPickerEmpty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: Material(
                type: MaterialType.transparency,
                clipBehavior: Clip.hardEdge,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlists.length,
                  itemBuilder: (context, index) {
                    final p = playlists[index];
                    return ListTile(
                      leading: const Icon(Icons.queue_music_rounded),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.pop(context, p.id),
                    );
                  },
                ),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.add),
            title: Text(context.l10n.playlistNewEllipsis),
            onTap: _createAndReturn,
          ),
        ],
      ),
    );
  }

  Future<void> _createAndReturn() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.playlistNew),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: context.l10n.commonName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.l10n.commonCreate),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final id = await ServiceLocator.songRepo.insertPlaylist(
      PlaylistsCompanion.insert(name: name, createdAt: now, updatedAt: now),
    );
    if (mounted) Navigator.pop(context, id);
  }
}
