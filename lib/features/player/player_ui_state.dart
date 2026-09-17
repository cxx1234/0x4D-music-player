import '../../core/models/lyric_text_size.dart';

/// 播放器 UI 界面状态：跨「打开/关闭」会话保留（App 持有，pop 不销毁）。
///
/// 需求：重开播放页时队列滚动位置、歌词/队列标签选择不重置。
/// 普通可变类即可——只在页面 init 时读、变更时写回，无需 ChangeNotifier。
class PlayerUiState {
  /// 宽模式右栏：队列(true) / 歌词(false)。默认显示歌词。
  bool showQueue = false;

  /// 窄模式当前标签（默认播放器）。
  NarrowTab narrowTab = NarrowTab.player;

  /// 队列滚动偏移（关闭时由 QueueView 存下，重开时恢复）。
  double queueScrollOffset = 0;

  /// 保存 [queueScrollOffset] 时队列的歌曲数。
  ///
  /// 用于判断"旧偏移是否属于当前队列"：队列被替换过（如 65 首 → 42 首）时
  /// 偏移就失效了，不能再拿去初始化新的列表——否则 ScrollPosition 会先在
  /// layout 中拿到一个超出范围的值、再被纠正，可能触发 Flutter 的
  /// `haveDimensions == (_lastMetrics != null)` 断言。
  int? queueScrollItemCount;

  /// 上次会话当前歌曲 id（null=尚无会话）。重开时用它判断是否跟随当前歌：
  /// 相同 → 恢复滚动位置；不同（离开期间切歌）→ 跟随当前歌。
  int? lastCurrentSongId;

  /// 歌词文本大小档位（跨会话保留，重开播放页不重置）。
  LyricTextSize lyricTextSize = LyricTextSize.medium;

  /// 是否显示翻译副行（跨会话保留，重开播放页不重置）。
  bool showTranslation = true;
}

/// 窄模式下的可切换标签：播放器 / 歌词 / 播放队列。
enum NarrowTab { player, lyrics, queue }
