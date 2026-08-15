/// 搜索匹配工具：统一查询归一化与大小写不敏感匹配。
///
/// 纯字符串函数，不依赖数据模型，便于各功能页复用与单测。
library;

/// 归一化搜索关键词：去首尾空白并转小写。空串/纯空白返回空串。
///
/// 调用方应把结果传给 [containsIgnoreCase] 使用。
String normalizeQuery(String? query) => (query ?? '').trim().toLowerCase();

/// 判断 [source] 是否包含查询词 [query]（大小写不敏感）。
///
/// [query] 应为 [normalizeQuery] 的结果（已 trim + 小写）；[source] 为
/// 原始字段值，内部转小写比较。查询为空或 [source] 为 null 时返回 false。
bool containsIgnoreCase(String? source, String query) {
  if (query.isEmpty || source == null || source.isEmpty) return false;
  return source.toLowerCase().contains(query);
}
