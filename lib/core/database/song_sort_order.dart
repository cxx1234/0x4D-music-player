/// 音乐库歌曲列表的排序方式。
enum SongSortOrder {
  title('标题'),
  dateAdded('最近添加'),
  playCount('常听'),
  year('年份');

  const SongSortOrder(this.label);

  /// 菜单展示用的中文标签。
  final String label;

  /// 从持久化的枚举名恢复；未知值回退到默认 [SongSortOrder.title]。
  static SongSortOrder fromName(String? name) {
    if (name == null) return SongSortOrder.title;
    return SongSortOrder.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SongSortOrder.title,
    );
  }
}
