import 'package:flutter/material.dart';

import '../../core/database/database.dart';
import '../../core/services/player_service.dart';
import '../../widgets/song_tile.dart';
import 'player_view_model.dart';

/// 队列底部状态行文案：跟随循环/随机模式变化。
///
/// - off + 未随机：顺序播放（滚动到底显示「· 到底了」）
/// - off + 随机：随机播放（滚动到底显示「· 到底了」）
/// - all：循环整个列表（可叠加随机）
/// - one：单曲循环
///
/// [atBottom]：列表滚动到底时传 true，追加「· 到底了」（仅不循环模式有意义）。
String queueFooterText(
  PlayerRepeatMode repeatMode,
  bool isShuffled, {
  bool atBottom = false,
}) {
  switch (repeatMode) {
    case PlayerRepeatMode.one:
      return '单曲循环播放';
    case PlayerRepeatMode.all:
      return isShuffled ? '随机 · 循环列表播放' : '循环列表播放';
    case PlayerRepeatMode.off:
      final base = isShuffled ? '随机播放' : '顺序播放';
      return atBottom ? '$base · 到底了' : base;
  }
}

/// 队列底部状态行图标：与文案同步。
IconData _queueFooterIcon(PlayerRepeatMode repeatMode, bool isShuffled) {
  switch (repeatMode) {
    case PlayerRepeatMode.one:
      return Icons.repeat_one_rounded;
    case PlayerRepeatMode.all:
      return Icons.repeat_rounded;
    case PlayerRepeatMode.off:
      return isShuffled ? Icons.shuffle_rounded : Icons.playlist_play_rounded;
  }
}

/// 当前播放队列视图：清空 / 选择删除 / 手动排序。
class QueueView extends StatefulWidget {
  final PlayerViewModel viewModel;
  final ThemeData theme;

  /// 窄版内嵌时传 true：「共 N 首」左侧加 margin（宽版右栏为 false，无 margin）。
  final bool isNarrow;

  const QueueView({
    super.key,
    required this.viewModel,
    required this.theme,
    this.isNarrow = false,
  });

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  bool _deleteMode = false;
  bool _reorderMode = false;
  final Set<int> _selectedIndices = {};
  final ScrollController _scrollController = ScrollController();

  // 工具条底部阴影：列表滚离顶部时出现（回顶消失）。
  bool _toolbarShadowed = false;
  // 状态行顶部阴影：列表滚离底部时出现（回底消失）。
  bool _footerShadowed = false;

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

  // 滚动到当前播放项并置于视口顶部（先快后慢 easeOutCubic，400ms）。
  void _scrollToCurrent() {
    if (!mounted) return;
    final index = vm.currentIndex;
    final queue = vm.queue;
    if (index < 0 || index >= queue.length) return;
    if (!_scrollController.hasClients) return;

    // 偏移 = index * 固定行高：当前项贴视口顶部（列表到底时钳制到底部）。
    final target = (index * _kQueueTileExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
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
      // 模式切换后列表重建，阴影状态一并复位。
      _toolbarShadowed = false;
      _footerShadowed = false;
    });
  }

  void _toggleReorderMode() {
    setState(() {
      _reorderMode = !_reorderMode;
      if (_reorderMode) {
        _deleteMode = false;
        _selectedIndices.clear();
      }
      _toolbarShadowed = false;
      _footerShadowed = false;
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
        // 工具条：列表滚离顶部时底部出现轻阴影（回顶消失）。
        AnimatedPhysicalModel(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          shape: BoxShape.rectangle,
          elevation: _toolbarShadowed ? 2 : 0,
          color: theme.colorScheme.surface,
          shadowColor: theme.colorScheme.shadow,
          child: _buildToolbar(queue.length),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScroll,
            child: Material(
              type: MaterialType.transparency,
              clipBehavior: Clip.hardEdge,
              child: _reorderMode
                  ? _buildReorderableList(queue)
                  : _buildList(queue),
            ),
          ),
        ),
        // 状态行：始终钉在底部；列表滚离底部时顶部出现一道向上渐变阴影（回底消失）。
        if (!_deleteMode && !_reorderMode) ...[
          AnimatedOpacity(
            opacity: _footerShadowed ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: IgnorePointer(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  // 仅向上投影：顶部透明 → 紧贴状态行顶边渐深，无侧向扩散。
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      theme.colorScheme.shadow.withValues(alpha: 0.14),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            color: theme.colorScheme.surface,
            child: _buildFooter(),
          ),
        ],
      ],
    );
  }

  // 滚动时更新两侧阴影：离开顶部 → 工具条阴影；离开底部 → 状态行阴影。
  bool _handleScroll(ScrollNotification notification) {
    final metrics = notification.metrics;
    final toolbarShadowed = metrics.extentBefore > 0;
    final footerShadowed = metrics.extentAfter > 0;
    if (toolbarShadowed != _toolbarShadowed ||
        footerShadowed != _footerShadowed) {
      setState(() {
        _toolbarShadowed = toolbarShadowed;
        _footerShadowed = footerShadowed;
      });
    }
    return false;
  }

  Widget _buildToolbar(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: widget.isNarrow ? 12 : 0),
            child: Text(
              '共 $count 首',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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

  Widget _buildFooter() {
    final icon = _queueFooterIcon(vm.repeatMode, vm.isShuffled);
    final text = queueFooterText(
      vm.repeatMode,
      vm.isShuffled,
      // 列表滚动到底（extentAfter == 0）时才显示「· 到底了」。
      atBottom: !_footerShadowed,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
