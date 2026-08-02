import 'package:flutter/material.dart';

import '../../core/database/database.dart';
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

  // 估算单行高度（ListTile 带副标题 ≈72，否则 ≈56），用于计算滚动偏移。
  static const double _tileWithSubtitle = 72;
  static const double _tileWithoutSubtitle = 56;

  double _estimateTileExtent(Song song) =>
      song.artist != null ? _tileWithSubtitle : _tileWithoutSubtitle;

  // 滚动到当前播放项并尽量居中显示。
  void _scrollToCurrent() {
    if (!mounted) return;
    final index = vm.currentIndex;
    final queue = vm.queue;
    if (index < 0 || index >= queue.length) return;
    if (!_scrollController.hasClients) return;

    // 累加当前项之前各行的高度作为目标偏移，再减去半个视口使目标居中。
    double offset = 0;
    for (var i = 0; i < index; i++) {
      offset += _estimateTileExtent(queue[i]);
    }
    offset -= _scrollController.position.viewportDimension / 2;
    final target = offset.clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  String _formatDuration(int? ms) {
    if (ms == null) return '';
    final d = Duration(milliseconds: ms);
    final min = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final sec = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$min:$sec';
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
    return ListTile(
      key: key,
      selected: isCurrent,
      selectedTileColor: theme.colorScheme.primary.withValues(alpha: 0.1),
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
              child: const Icon(Icons.drag_handle, size: 20),
            )
          : (isCurrent
                ? Icon(
                    Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  )
                : SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: isCurrent ? FontWeight.bold : null,
          color: isCurrent ? theme.colorScheme.primary : null,
        ),
      ),
      subtitle: song.artist != null
          ? Text(
              song.artist!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: song.durationMs != null
          ? Text(
              _formatDuration(song.durationMs),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
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
    );
  }
}
