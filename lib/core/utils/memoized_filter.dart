/// 搜索过滤结果的一键缓存。
///
/// 列表页的 `_filteredXxx` getter 每次 build 都会对全量列表做一次 O(n)
/// 过滤;但页面常因其它原因触发 build（数据刷新、播放态切换、切 tab 保活
/// 重建等）,此时 query 与源列表都没变,重算纯属浪费。
///
/// 本类缓存 (query, 源列表实例) → 结果：二者均未变时直接复用上次结果。
/// 源列表由 ViewModel 在 `load()` 时**整体替换引用**,因此用 `identical`
/// 比较源即可——数据一变引用就变,缓存自动失效,无需手动清空。
///
/// 空 query 直接返回源列表本身（无拷贝,与各页面原有行为一致）。
///
/// 缓存实例应作为页面 State 的字段持有,生命周期随 State 创建/销毁。
class QueryFilterCache<T> {
  String? _query;
  List<T>? _source;
  List<T>? _result;

  /// 返回过滤结果。
  ///
  /// [query] 应为已归一化的查询串（与页面原逻辑一致,调用方自行
  /// `normalizeQuery`）;[filter] 负责实际的 where+toList。
  List<T> get(
    String query,
    List<T> source,
    List<T> Function(String query, List<T> source) filter,
  ) {
    if (query.isEmpty) return source;
    if (query == _query && identical(source, _source)) {
      return _result!;
    }
    _query = query;
    _source = source;
    final result = filter(query, source);
    _result = result;
    return result;
  }
}
