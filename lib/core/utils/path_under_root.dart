import 'package:path/path.dart' as p;

/// 路径是否位于 [root] 下（含与根相等）。
///
/// 边界语义：等于根本身，或根后紧跟 `/`——避免把「名字以 root 开头」的兄弟
/// 目录（如 `/a/Music` 与 `/a/Music2`）算作根内。
///
/// 与 SQL 侧 `filePath = root OR filePath LIKE 'root/%'` 配合使用：LIKE 只作
/// **粗筛**（路径里的 `_`/`%` 会被 SQLite 当作通配符，从而**多**匹配兄弟目录，
/// 但绝不会漏掉真实前缀），随后由本函数做精确判定。这样无需依赖 SQL 的
/// `ESCAPE` 转义，也保证 Dart 与 SQL 两侧语义一致。
bool isUnderRootPath(String path, String root) {
  final r = p.normalize(root);
  final target = p.normalize(path);
  if (target == r) return true;
  return target.startsWith('$r/');
}
