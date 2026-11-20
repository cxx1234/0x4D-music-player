import 'dart:io' show Platform;

import 'package:path/path.dart' as p;

import '../database/database.dart';
import 'm3u.dart';

/// 一条 M3U 条目的命中层级，越靠前证据越强。
enum M3uMatchTier {
  /// 路径字符串完全相等。
  path,

  /// 归一化后的路径相等（macOS / Windows 下大小写不敏感）。
  normalizedPath,

  /// 去掉扩展名后的「父目录名 + 文件名」相同：换容器（flac ↔ m4a）仍可命中。
  name,

  /// 元数据指纹相同（`#EXTINF` 的 `Artist - Title` + 时长）：跨格式的主力。
  metadata,
}

/// 一条命中记录。
class M3uMatch {
  final M3uEntry entry;
  final Song song;
  final M3uMatchTier tier;

  const M3uMatch({required this.entry, required this.song, required this.tier});
}

/// 整份 M3U 的匹配报告。
class M3uMatchReport {
  /// 命中的条目，按文件顺序去重（同一首歌只保留首次命中）。
  final List<M3uMatch> matches;

  /// 文件中的路径条目总数。
  final int total;

  /// 文件内重复出现、已跳过的条目数。
  final int duplicates;

  const M3uMatchReport({
    required this.matches,
    required this.total,
    required this.duplicates,
  });

  List<Song> get songs => [for (final match in matches) match.song];

  /// 靠路径（精确或归一化）命中的条目数。
  int get matchedByPath => matches
      .where(
        (m) =>
            m.tier == M3uMatchTier.path ||
            m.tier == M3uMatchTier.normalizedPath,
      )
      .length;

  /// 靠名称或元数据命中的条目数——这些歌在本机的路径与 m3u 里不同。
  int get matchedByMetadata => matches.length - matchedByPath;

  /// 没有匹配到任何库中歌曲的条目数（不含重复项）。
  int get skipped => total - matches.length - duplicates;
}

/// 按「路径 → 归一化路径 → 目录+文件名 → 元数据」分级匹配 m3u 条目。
///
/// 每一级只在候选唯一（或确认是同一首歌的多份拷贝）时命中，绝不靠猜测：
/// 拿不准就落到下一级，最后计入未匹配。库中不可用的歌曲（文件已删）不参与匹配。
///
/// [caseInsensitivePaths] 默认按当前平台推断（macOS / Windows 大小写不敏感），
/// 测试可显式指定。
M3uMatchReport matchM3uEntries({
  required List<M3uEntry> entries,
  required List<Song> library,
  required String baseDir,
  String? homeDir,
  bool? caseInsensitivePaths,
}) {
  final caseInsensitive =
      caseInsensitivePaths ?? (Platform.isMacOS || Platform.isWindows);

  final byExactPath = <String, Song>{};
  final byPathKey = <String, Song>{};
  final byName = <String, List<Song>>{};
  final byLabel = <String, List<Song>>{};
  final byArtistTitle = <String, List<Song>>{};
  final byTitle = <String, List<Song>>{};

  for (final song in library) {
    if (song.isAvailable != 1) continue;

    byExactPath[song.filePath] = song;
    byPathKey.putIfAbsent(
      _pathKey(song.filePath, caseInsensitive: caseInsensitive),
      () => song,
    );

    _add(byName, _nameKeyOfPath(song.filePath), song);
    _add(byLabel, normalizeMatchText(_labelOf(song)), song);
    _add(byTitle, normalizeMatchText(song.title), song);

    final artist = normalizeMatchText(song.artist);
    if (artist.isNotEmpty) {
      _add(byArtistTitle, '$artist|${normalizeMatchText(song.title)}', song);
    }
  }

  final matches = <M3uMatch>[];
  final seenSongIds = <int>{};
  var duplicates = 0;

  for (final entry in entries) {
    final resolved = resolveM3uPath(entry.path, baseDir, homeDir: homeDir);
    final match = _matchEntry(
      entry: entry,
      resolved: resolved,
      caseInsensitive: caseInsensitive,
      byExactPath: byExactPath,
      byPathKey: byPathKey,
      byName: byName,
      byLabel: byLabel,
      byArtistTitle: byArtistTitle,
      byTitle: byTitle,
    );
    if (match == null) continue;

    if (!seenSongIds.add(match.song.id)) {
      duplicates++;
      continue;
    }
    matches.add(match);
  }

  return M3uMatchReport(
    matches: matches,
    total: entries.length,
    duplicates: duplicates,
  );
}

/// 元数据比较用的归一化：小写、折叠空白、去掉常见标点。
///
/// 只抹平打标工具/编码器带来的表面差异；`-` 刻意保留，因为 `Artist - Title`
/// 的分隔符两侧都要参与比较。
String normalizeMatchText(String? text) {
  if (text == null) return '';
  final lowered = text
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\u3000]+'), ' ')
      .trim();
  return lowered.replaceAll(
    RegExp(r'''[.,!?;:'"()\[\]{}<>《》〈〉「」『』、，。！？；：]'''),
    '',
  );
}

M3uMatch? _matchEntry({
  required M3uEntry entry,
  required String resolved,
  required bool caseInsensitive,
  required Map<String, Song> byExactPath,
  required Map<String, Song> byPathKey,
  required Map<String, List<Song>> byName,
  required Map<String, List<Song>> byLabel,
  required Map<String, List<Song>> byArtistTitle,
  required Map<String, List<Song>> byTitle,
}) {
  final exact = byExactPath[resolved] ?? byExactPath[entry.path];
  if (exact != null) {
    return M3uMatch(entry: entry, song: exact, tier: M3uMatchTier.path);
  }

  final normalized =
      byPathKey[_pathKey(resolved, caseInsensitive: caseInsensitive)];
  if (normalized != null) {
    return M3uMatch(
      entry: entry,
      song: normalized,
      tier: M3uMatchTier.normalizedPath,
    );
  }

  final byNameHit = _select(
    byName[_nameKeyOfPath(resolved)],
    entry: entry,
    allowPreference: true,
  );
  if (byNameHit != null) {
    return M3uMatch(entry: entry, song: byNameHit, tier: M3uMatchTier.name);
  }

  final label = entry.label;
  if (label == null) return null;

  final artistTag = entry.artist;
  if (artistTag != null) {
    final artist = normalizeMatchText(artistTag);
    final title = normalizeMatchText(_stripArtistPrefix(label, artistTag));
    final hit = _select(
      byArtistTitle['$artist|$title'],
      entry: entry,
      allowPreference: true,
    );
    if (hit != null) {
      return M3uMatch(entry: entry, song: hit, tier: M3uMatchTier.metadata);
    }
  }

  final byFullLabel = _select(
    byLabel[normalizeMatchText(label)],
    entry: entry,
    allowPreference: true,
  );
  if (byFullLabel != null) {
    return M3uMatch(
      entry: entry,
      song: byFullLabel,
      tier: M3uMatchTier.metadata,
    );
  }

  // 标签只有标题（或本机歌手标签与来源不同）时退回按标题匹配。
  // 证据弱，因此要求候选唯一，不做偏好挑选。
  final byTitleHit = _select(
    byTitle[normalizeMatchText(_titleCandidate(label))],
    entry: entry,
    allowPreference: false,
  );
  if (byTitleHit != null) {
    return M3uMatch(
      entry: entry,
      song: byTitleHit,
      tier: M3uMatchTier.metadata,
    );
  }

  return null;
}

/// 在候选里挑一首：先用时长/专辑收窄，唯一则命中。
///
/// [allowPreference] 为真时，收窄后仍是多个候选就按确定性规则挑一个
/// （同一首歌的多份拷贝：flac / m4a 各一份）；为假时视为歧义、返回 null。
Song? _select(
  List<Song>? candidates, {
  required M3uEntry entry,
  required bool allowPreference,
}) {
  if (candidates == null || candidates.isEmpty) return null;

  var pool = candidates;
  if (pool.length > 1 && entry.durationSeconds > 0) {
    pool = _narrowByDuration(pool, entry.durationSeconds);
  }
  if (pool.length > 1) {
    pool = _narrowByAlbum(pool, entry.album);
  }
  if (pool.length == 1) return pool.single;
  if (!allowPreference) return null;
  return _preferred(pool);
}

List<Song> _narrowByDuration(List<Song> pool, int seconds) {
  for (final tolerance in const [1, 3]) {
    final narrowed = [
      for (final song in pool)
        if (song.durationMs != null &&
            ((song.durationMs! ~/ 1000) - seconds).abs() <= tolerance)
          song,
    ];
    if (narrowed.isNotEmpty) return narrowed;
  }
  return pool;
}

List<Song> _narrowByAlbum(List<Song> pool, String? album) {
  final key = normalizeMatchText(album);
  if (key.isEmpty) return pool;
  final narrowed = [
    for (final song in pool)
      if (normalizeMatchText(song.album) == key) song,
  ];
  return narrowed.isEmpty ? pool : narrowed;
}

const _losslessExtensions = {'flac', 'alac', 'wav', 'aiff', 'aif', 'ape', 'wv'};

bool _isLossless(Song song) => _losslessExtensions.contains(
  p.extension(song.filePath).toLowerCase().replaceFirst('.', ''),
);

/// 同一首歌有多份拷贝时的确定性取舍：无损优先，其次 id 最小。
Song _preferred(List<Song> pool) {
  final sorted = [...pool]
    ..sort((a, b) {
      final aLossless = _isLossless(a);
      final bLossless = _isLossless(b);
      if (aLossless != bLossless) return bLossless ? 1 : -1;
      return a.id.compareTo(b.id);
    });
  return sorted.first;
}

String _pathKey(String path, {required bool caseInsensitive}) {
  final normalized = p.normalize(path);
  return caseInsensitive ? normalized.toLowerCase() : normalized;
}

String _nameKeyOfPath(String path) {
  final albumDir = p.basename(p.dirname(path));
  final stem = p.basenameWithoutExtension(path);
  return '${normalizeMatchText(albumDir)}/${normalizeMatchText(stem)}';
}

String _labelOf(Song song) {
  final artist = (song.artist ?? '').trim();
  return artist.isEmpty ? song.title : '$artist - ${song.title}';
}

/// 从 `Artist - Title` 里剥掉歌手前缀（歌手匹配时），否则原样返回。
String _stripArtistPrefix(String label, String artist) {
  final separator = label.indexOf(' - ');
  if (separator < 0) return label;
  final head = label.substring(0, separator);
  if (normalizeMatchText(head) != normalizeMatchText(artist)) return label;
  return label.substring(separator + 3);
}

/// 标签里可当作标题的部分：`Artist - Title` 取分隔符之后，否则整串。
String _titleCandidate(String label) {
  final separator = label.indexOf(' - ');
  return separator < 0 ? label : label.substring(separator + 3);
}

void _add(Map<String, List<Song>> index, String key, Song song) {
  if (key.isEmpty) return;
  (index[key] ??= <Song>[]).add(song);
}
