import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/service_locator.dart';
import '../../widgets/cached_album_art.dart';

/// 打开"添加歌曲到播放列表"的底部弹层，返回实际添加数量（可为 0）。
Future<int?> showAddSongsSheet(BuildContext context, int playlistId) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => AddSongsSheet(playlistId: playlistId),
  );
}

class AddSongsSheet extends StatefulWidget {
  final int playlistId;

  const AddSongsSheet({super.key, required this.playlistId});

  @override
  State<AddSongsSheet> createState() => _AddSongsSheetState();
}

class _AddSongsSheetState extends State<AddSongsSheet> {
  List<Song> _allSongs = [];
  List<Song> _filtered = [];
  final Set<int> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final songs = await ServiceLocator.songRepo.getAvailableSongs();
    if (!mounted) return;
    setState(() {
      _allSongs = songs;
      _filtered = songs;
      _loading = false;
    });
  }

  void _onQueryChanged(String value) {
    setState(() {
      final q = value.trim().toLowerCase();
      _filtered = q.isEmpty
          ? _allSongs
          : _allSongs
                .where(
                  (s) =>
                      s.title.toLowerCase().contains(q) ||
                      (s.artist?.toLowerCase().contains(q) ?? false) ||
                      (s.album?.toLowerCase().contains(q) ?? false),
                )
                .toList();
    });
  }

  Future<void> _confirm() async {
    final count = await ServiceLocator.songRepo.addSongsToPlaylist(
      widget.playlistId,
      _selected.toList(),
    );
    if (mounted) Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: '搜索歌曲',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _onQueryChanged,
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                  ? Center(
                      child: Text(
                        '没有匹配的歌曲',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final song = _filtered[index];
                        final checked = _selected.contains(song.id);
                        return CheckboxListTile(
                          value: checked,
                          dense: true,
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: song.artist != null
                              ? Text(
                                  song.artist!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                )
                              : null,
                          secondary: SizedBox(
                            width: 40,
                            height: 40,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: CachedAlbumArt(
                                albumArtFilePath: song.albumArtFilePath,
                                hasEmbeddedArt: song.hasEmbeddedArt == 1,
                                size: 40,
                                borderRadius: 6,
                              ),
                            ),
                          ),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(song.id);
                              } else {
                                _selected.remove(song.id);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _selected.isEmpty ? null : _confirm,
                    child: Text(
                      _selected.isEmpty ? '选择歌曲' : '添加 (${_selected.length})',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
