import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../widgets/song_tile.dart';
import 'player_view_model.dart';

/// 当前播放队列视图：清空 / 选择删除 / 手动排序。
class QueueView extends StatefulWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;

  const QueueView({super.key, required this.viewModel, required this.theme});

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  bool _deleteMode = false;
  bool _reorderMode = false;
  final Set<int> _selectedIndices = {};
  final ScrollController _scrollController = ScrollController();

  // 上次已知的当前播放索引；变化时自动滚动到高亮项。
  int? _lastCurrentIndex;

  PlayerViewModel get vm => widget.viewModel;
  ThemeData get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _lastCurrentIndex = vm.currentIndex;
    // 首次打开队列即定位到当前播放项（高亮可见）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void didUpdateWidget(QueueView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_lastCurrentIndex != vm.currentIndex) {
      _lastCurrentIndex = vm.currentIndex;
      // 当前播放项变化后自动滚动到高亮位置（删除/拖拽模式下不打扰用户）。
      if (!_deleteMode && !_reorderMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 队列固定行高：itemExtent 保证滚动偏移精确（index * extent），
  // 不会像“逐行估算高度”那样在大列表下累积误差导致高亮滚动失效。
  static const double _kQueueTileExtent = 72;

  // 滚动到当前播放项并尽量居中显示（先快后慢 easeOutCubic，400ms）。
  void _scrollToCurrent() {
    if (!mounted) return;
    final index = vm.currentIndex;
    final queue = vm.queue;
    if (index < 0 || index >= queue.length) return;
    if (!_scrollController.hasClients) return;

    // 偏移 = index * 固定行高，再减去半个视口使目标居中。
    final target =
        (index * _kQueueTileExtent -
                _scrollController.position.viewportDimension / 2)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleDeleteMode() {
    setState(() {
      _deleteMode = !_deleteMode;
      if (!_deleteMode) {
        _selectedIndices.clear();
      }
      _reorderMode = false;
    });
  }

  void _toggleReorderMode() {
    setState(() {
      _reorderMode = !_reorderMode;
      if (_reorderMode) {
        _deleteMode = false;
        _selectedIndices.clear();
      }
    });
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('确定要清空当前播放列表吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await vm.clearQueue();
    }
  }

  Future<void> _deleteSelected() async {
    // Sort descending so indices stay valid after removal
    final sorted = _selectedIndices.toList()..sort((a, b) => b.compareTo(a));
    for (final i in sorted) {
      await vm.removeFromQueue(i);
    }
    setState(() {
      _selectedIndices.clear();
      _deleteMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queue = vm.queue;
    if (queue.isEmpty) {
      return Center(
        child: Text(
          '播放列表为空',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildToolbar(queue.length),
        Expanded(
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.hardEdge,
            child: _reorderMode
                ? _buildReorderableList(queue)
                : _buildList(queue),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(
            '共 $count 首',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          if (_deleteMode) ...[
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: '取消',
              onPressed: _toggleDeleteMode,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(
                Icons.delete_rounded,
                size: 20,
                color: _selectedIndices.isNotEmpty
                    ? theme.colorScheme.error
                    : null,
              ),
              tooltip: '删除选中 (${_selectedIndices.length})',
              onPressed: _selectedIndices.isNotEmpty ? _deleteSelected : null,
            ),
          ] else if (_reorderMode) ...[
            IconButton(
              icon: const Icon(Icons.check, size: 20),
              tooltip: '完成排序',
              onPressed: _toggleReorderMode,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, size: 20),
              tooltip: '清空列表',
              onPressed: _confirmClear,
            ),
            IconButton(
              icon: const Icon(Icons.checklist_rounded, size: 20),
              tooltip: '选择删除',
              onPressed: _toggleDeleteMode,
            ),
            IconButton(
              icon: const Icon(Icons.reorder_rounded, size: 20),
              tooltip: '手动排序',
              onPressed: _toggleReorderMode,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(List<Song> queue) {
    return ListView.builder(
      controller: _scrollController,
      itemExtent: _kQueueTileExtent,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: queue.length,
      itemBuilder: (context, index) {
        final song = queue[index];
        final isCurrent = index == vm.currentIndex;
        return _buildListTile(song, index, isCurrent);
      },
    );
  }

  Widget _buildReorderableList(List<Song> queue) {
    return ReorderableListView.builder(
      scrollController: _scrollController,
      itemExtent: _kQueueTileExtent,
      padding: const EdgeInsets.symmetric(vertical: 4),
      buildDefaultDragHandles: false,
      itemCount: queue.length,
      onReorderItem: (oldIndex, newIndex) {
        vm.moveInQueue(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        final song = queue[index];
        final isCurrent = index == vm.currentIndex;
        return _buildListTile(
          song,
          index,
          isCurrent,
          key: ValueKey(song.filePath),
        );
      },
    );
  }

  Widget _buildListTile(Song song, int index, bool isCurrent, {Key? key}) {
    return SongTile(
      key: key,
      song: song,
      isCurrentSong: isCurrent,
      // 队列用 leading 指示当前项（播放图标/序号），隐藏行尾音量图标避免重复
      showCurrentIndicator: false,
      onTap: _deleteMode
          ? () {
              setState(() {
                if (_selectedIndices.contains(index)) {
                  _selectedIndices.remove(index);
                } else {
                  _selectedIndices.add(index);
                }
              });
            }
          : (isCurrent ? null : () => vm.jumpTo(index)),
      leading: _deleteMode
          ? Checkbox(
              value: _selectedIndices.contains(index),
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selectedIndices.add(index);
                  } else {
                    _selectedIndices.remove(index);
                  }
                });
              },
            )
          : _reorderMode
          ? ReorderableDragStartListener(
              index: index,
              child: SizedBox(
                width: 36,
                height: 32,
                child: Center(
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : SizedBox(
              width: 36,
              height: 32,
              child: Center(
                child: isCurrent
                    ? Icon(
                        Icons.play_arrow_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      )
                    : Text(
                        '${index + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
    );
  }
}
