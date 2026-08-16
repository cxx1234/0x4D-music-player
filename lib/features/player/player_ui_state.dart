/// 播放器 UI 界面状态：跨「打开/关闭」会话保留（App 持有，pop 不销毁）。
///
/// 需求：重开播放页时队列滚动位置、歌词/队列标签选择不重置。
/// 普通可变类即可——只在页面 init 时读、变更时写回，无需 ChangeNotifier。
class PlayerUiState {
  /// 宽模式右栏：队列(true) / 歌词(false)。
  bool showQueue = true;

  /// 窄模式当前标签（默认播放器）。
  NarrowTab narrowTab = NarrowTab.player;

  /// 队列滚动偏移（关闭时由 QueueView 存下，重开时恢复）。
  double queueScrollOffset = 0;

  /// 上次会话当前歌曲 id（null=尚无会话）。重开时用它判断是否跟随当前歌：
  /// 相同 → 恢复滚动位置；不同（离开期间切歌）→ 跟随当前歌。
  int? lastCurrentSongId;
}

/// 窄模式下的可切换标签：播放器 / 歌词 / 播放队列。
enum NarrowTab { player, lyrics, queue }
