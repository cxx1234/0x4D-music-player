import 'package:path/path.dart' as p;

import '../database/database.dart';

/// M3U / M3U8 播放列表的序列化与解析（纯函数，便于单元测试）。

/// M3U 中的一条条目：路径行 + 它前面 `#EXTINF` 块里的元数据。
class M3uEntry {
  /// 文件路径（原样，未按 m3u 所在目录解析）。
  final String path;

  /// `#EXTINF` 的时长（秒）；缺失或无法解析时为 0。
  final int durationSeconds;

  /// `#EXTINF` 首个逗号后的文本；本应用写 `Artist - Title`。
  final String? label;

  /// 条目自带的 `#EXTART`（歌手）。
  final String? artist;

  /// 条目自带的 `#EXTALB`（专辑）。
  final String? album;

  const M3uEntry({
    required this.path,
    this.durationSeconds = 0,
    this.label,
    this.artist,
    this.album,
  });
}

/// 把歌曲列表序列化为扩展 M3U8（UTF-8）内容：
/// - `#EXTM3U` 头
/// - 每首：`#EXTINF:<秒数>,<歌手> - <标题>`、可选的 `#EXTART` / `#EXTALB`，
///   然后是绝对路径行
///
/// `#EXTINF` 写成 `Artist - Title` 而不是只写标题：跨设备导入时路径不可用，
/// 元数据是唯一能对齐同一首歌的线索。
String buildM3u8(List<Song> songs) {
  final buffer = StringBuffer('#EXTM3U\n');
  for (final song in songs) {
    final title = _oneLine(song.title);
    final artist = _oneLine(song.artist ?? '');
    final album = _oneLine(song.album ?? '');
    final label = artist.isEmpty ? title : '$artist - $title';
    final seconds = (song.durationMs ?? 0) ~/ 1000;
    buffer.write('#EXTINF:$seconds,$label\n');
    if (artist.isNotEmpty) buffer.write('#EXTART:$artist\n');
    if (album.isNotEmpty) buffer.write('#EXTALB:$album\n');
    buffer.write('${song.filePath}\n');
  }
  return buffer.toString();
}

/// 解析 M3U/M3U8 内容，返回条目列表（`#` 注释与空行不作为条目）。
///
/// `#EXTINF` / `#EXTART` / `#EXTALB` 会挂到紧随其后的路径行上；其它 `#` 行忽略。
/// 一个 `#EXTINF` 后若没有路径行（文件被截断），该块直接丢弃。
List<M3uEntry> parseM3u(String content) {
  final entries = <M3uEntry>[];
  var durationSeconds = 0;
  String? label;
  String? artist;
  String? album;

  for (final line in content.split(RegExp(r'\r?\n'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.startsWith('#')) {
      final upper = trimmed.toUpperCase();
      if (upper.startsWith('#EXTINF:')) {
        final payload = trimmed.substring('#EXTINF:'.length);
        final comma = payload.indexOf(',');
        final seconds = comma < 0 ? payload : payload.substring(0, comma);
        // 部分播放器写小数秒（`#EXTINF:243.5,`）。
        durationSeconds = (double.tryParse(seconds.trim()) ?? 0).round();
        label = comma < 0 ? null : _nonEmpty(payload.substring(comma + 1));
      } else if (upper.startsWith('#EXTART:')) {
        artist = _nonEmpty(trimmed.substring('#EXTART:'.length));
      } else if (upper.startsWith('#EXTALB:')) {
        album = _nonEmpty(trimmed.substring('#EXTALB:'.length));
      }
      continue;
    }

    entries.add(
      M3uEntry(
        path: trimmed,
        durationSeconds: durationSeconds,
        label: label,
        artist: artist,
        album: album,
      ),
    );
    durationSeconds = 0;
    label = null;
    artist = null;
    album = null;
  }
  return entries;
}

/// 把 M3U 中的路径解析为绝对路径：
/// - `file://` URI → 本地路径
/// - `~` / `~/...` → [homeDir]（未提供时原样保留）
/// - 已是绝对路径 → 归一化后返回
/// - 相对路径 → 以 [baseDir]（M3U 文件所在目录）为基准拼接并归一化
String resolveM3uPath(String rawPath, String baseDir, {String? homeDir}) {
  var path = rawPath.trim();

  if (path.toLowerCase().startsWith('file:')) {
    try {
      final parsed = Uri.parse(path);
      // 只接受 `file:` + 空 host 的形式；UNC（`file://host/...`）等其余写法
      // 退回到「去掉 scheme」当作普通路径处理。
      path = parsed.scheme == 'file' && parsed.host.isEmpty
          ? parsed.toFilePath()
          : path.substring('file:'.length);
    } on FormatException {
      path = path.substring('file:'.length);
    }
  }
  if (homeDir != null && (path == '~' || path.startsWith('~/'))) {
    final rest = path.substring(1);
    path = rest.isEmpty ? homeDir : p.join(homeDir, rest.substring(1));
  }
  if (p.isAbsolute(path)) return p.normalize(path);
  return p.normalize(p.join(baseDir, path));
}

/// 压平换行与连续空白：`#EXTINF` / 扩展标签都是单行字段。
String _oneLine(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

String? _nonEmpty(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
