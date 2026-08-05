import 'package:path/path.dart' as p;

import '../database/database.dart';

/// M3U / M3U8 播放列表的序列化与解析（纯函数，便于单元测试）。

/// 把歌曲列表序列化为扩展 M3U8（UTF-8）内容：
/// - `#EXTM3U` 头
/// - 每首：`#EXTINF:<秒数>,<标题>` + 绝对路径行
String buildM3u8(List<Song> songs) {
  final buffer = StringBuffer('#EXTM3U\n');
  for (final song in songs) {
    final title = song.title.replaceAll('\n', ' ').replaceAll('\r', ' ');
    final seconds = (song.durationMs ?? 0) ~/ 1000;
    buffer.write('#EXTINF:$seconds,$title\n');
    buffer.write('${song.filePath}\n');
  }
  return buffer.toString();
}

/// 解析 M3U/M3U8 内容，返回原始路径行（去掉 `#` 注释/EXTINF 行与空行）。
List<String> parseM3u(String content) {
  final paths = <String>[];
  final lines = content.split(RegExp(r'\r?\n'));
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#')) continue;
    paths.add(trimmed);
  }
  return paths;
}

/// 把 M3U 中的路径解析为绝对路径：
/// - 已是绝对路径 → 原样返回
/// - 相对路径 → 以 [baseDir]（M3U 文件所在目录）为基准拼接并归一化
String resolveM3uPath(String rawPath, String baseDir) {
  if (p.isAbsolute(rawPath)) return rawPath;
  return p.normalize(p.join(baseDir, rawPath));
}
