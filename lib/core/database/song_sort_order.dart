/// 音乐库歌曲列表的排序方式。
///
/// 展示文案见 `lib/l10n/enum_labels.dart`。
enum SongSortOrder {
  title,
  dateAdded,
  playCount,
  year;

  /// 从持久化的枚举名恢复；未知值回退到默认 [SongSortOrder.title]。
  static SongSortOrder fromName(String? name) {
    if (name == null) return SongSortOrder.title;
    return SongSortOrder.values.firstWhere(
      (e) => e.name == name,
      orElse: () => SongSortOrder.title,
    );
  }
}
