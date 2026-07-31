import 'package:lpinyin/lpinyin.dart';

/// 日文假名（平假名 + 片假名）的 Unicode 区间。
///
/// 含假名的标题判定为日文，不做拼音转换。
final RegExp _kanaPattern = RegExp(r'[\u3040-\u309F\u30A0-\u30FF]');

/// 生成排序键，供数据库 `*_sort_key` 列使用。
///
/// - 含日文假名（平假名/片假名）→ 不做拼音转换，返回原文小写。
///   Unicode 码点顺序近似五十音順，中文/拉丁按码点排其后。
/// - 否则 → lpinyin 小写全拼；非中文字符（拉丁、数字、符号）原样保留。
/// - 空字符串 → 返回空串。
String buildSortKey(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return '';
  if (_kanaPattern.hasMatch(trimmed)) {
    return trimmed.toLowerCase();
  }
  return PinyinHelper.getPinyinE(
    trimmed,
    separator: '',
    defPinyin: '',
  ).toLowerCase();
}
