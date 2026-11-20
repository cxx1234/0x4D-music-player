import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:txvziwm/core/database/database.dart';
import 'package:txvziwm/core/utils/m3u.dart';
import 'package:txvziwm/core/utils/m3u_match.dart';

Song _song({
  required int id,
  required String filePath,
  String title = 'Song',
  String? artist,
  String? album,
  int? durationMs,
  int isAvailable = 1,
}) => Song(
  id: id,
  title: title,
  artist: artist,
  album: album,
  filePath: filePath,
  fileName: p.basename(filePath),
  hasEmbeddedArt: 0,
  hasEmbeddedLyrics: 0,
  dateAdded: DateTime(2024),
  playCount: 0,
  isFavorite: 0,
  isAvailable: isAvailable,
  durationMs: durationMs,
);

M3uMatchReport _run(
  String content,
  List<Song> library, {
  String baseDir = '/m3u',
  bool caseInsensitivePaths = false,
}) => matchM3uEntries(
  entries: parseM3u(content),
  library: library,
  baseDir: baseDir,
  caseInsensitivePaths: caseInsensitivePaths,
);

void main() {
  test('路径完全相等时按 path 命中', () {
    final report = _run('/music/a.mp3\n', [
      _song(id: 1, filePath: '/music/a.mp3'),
    ]);

    expect(report.matches.single.tier, M3uMatchTier.path);
    expect(report.matchedByPath, 1);
    expect(report.matchedByMetadata, 0);
    expect(report.skipped, 0);
  });

  test('相对路径按 m3u 所在目录解析后命中', () {
    final report = _run('a.mp3\n', [_song(id: 1, filePath: '/m3u/a.mp3')]);

    expect(report.matches.single.tier, M3uMatchTier.path);
  });

  test('大小写不同的路径在大小写不敏感平台上命中', () {
    final report = _run('/Music/A.mp3\n', [
      _song(id: 1, filePath: '/music/a.mp3'),
    ], caseInsensitivePaths: true);

    expect(report.matches.single.tier, M3uMatchTier.normalizedPath);
    expect(report.matchedByPath, 1);
  });

  test('只有容器不同（flac → m4a）时按目录 + 文件名命中', () {
    final report = _run('#EXTINF:200,X - Intro\n/old/Album/01 Intro.flac\n', [
      _song(
        id: 1,
        filePath: '/new/Album/01 Intro.m4a',
        title: 'Intro',
        artist: 'X',
        durationMs: 200000,
      ),
    ]);

    expect(report.matches.single.tier, M3uMatchTier.name);
    expect(report.matchedByMetadata, 1);
    expect(report.matchedByPath, 0);
  });

  test('路径与目录都不同时按 Artis - Title 元数据命中', () {
    final report = _run('#EXTINF:240,A - Song X\n/old/A/Alb/01 Song X.flac\n', [
      _song(
        id: 1,
        filePath: '/new/Whatever/zzz.m4a',
        title: 'Song X',
        artist: 'A',
        album: 'Alb',
        durationMs: 241000,
      ),
    ]);

    expect(report.matches.single.tier, M3uMatchTier.metadata);
    expect(report.matchedByMetadata, 1);
  });

  test('有 EXTART 时即使标签只写标题也能按歌手 + 标题命中', () {
    final report = _run('#EXTINF:200,Song X\n#EXTART:A\n/old/x.flac\n', [
      _song(
        id: 1,
        filePath: '/new/y.m4a',
        title: 'Song X',
        artist: 'A',
        durationMs: 200000,
      ),
    ]);

    expect(report.matches.single.tier, M3uMatchTier.metadata);
  });

  test('标签只有标题且同名多首时不猜，计为未匹配', () {
    final report = _run('#EXTINF:100,Intro\n/old/Other/01 Intro.mp3\n', [
      _song(
        id: 1,
        filePath: '/lib/AlbA/01 Intro.mp3',
        title: 'Intro',
        artist: 'A',
        durationMs: 100000,
      ),
      _song(
        id: 2,
        filePath: '/lib/AlbB/01 Intro.mp3',
        title: 'Intro',
        artist: 'B',
        durationMs: 100000,
      ),
    ]);

    expect(report.matches, isEmpty);
    expect(report.skipped, 1);
  });

  test('时长把专辑版与现场版区分开', () {
    final report = _run('#EXTINF:260,A - Song\n/old/x/Song.flac\n', [
      _song(
        id: 1,
        filePath: '/lib/album/Song.flac',
        title: 'Song',
        artist: 'A',
        durationMs: 200000,
      ),
      _song(
        id: 2,
        filePath: '/lib/live/Song.flac',
        title: 'Song',
        artist: 'A',
        durationMs: 260000,
      ),
    ]);

    expect(report.matches.single.song.id, 2);
  });

  test('同一首歌有 flac 与 m4a 两份拷贝时优先无损', () {
    final report = _run('#EXTINF:200,A - Song\n/old/x/01 Song.flac\n', [
      _song(
        id: 1,
        filePath: '/lib/01 Song.m4a',
        title: 'Song',
        artist: 'A',
        durationMs: 200000,
      ),
      _song(
        id: 2,
        filePath: '/lib/01 Song.flac',
        title: 'Song',
        artist: 'A',
        durationMs: 200000,
      ),
    ]);

    expect(report.matches.single.song.id, 2);
  });

  test('文件已删除（is_available = 0）的行不参与匹配', () {
    final report = _run('/music/a.mp3\n', [
      _song(id: 1, filePath: '/music/a.mp3', isAvailable: 0),
    ]);

    expect(report.matches, isEmpty);
    expect(report.skipped, 1);
  });

  test('文件内重复条目只导入一次，且不计入未匹配', () {
    final report = _run('/music/a.mp3\n/music/a.mp3\n', [
      _song(id: 1, filePath: '/music/a.mp3'),
    ]);

    expect(report.matches, hasLength(1));
    expect(report.total, 2);
    expect(report.duplicates, 1);
    expect(report.skipped, 0);
  });

  test('导出后换设备导入：根目录与容器都不同也能全部命中', () {
    final source = [
      _song(
        id: 1,
        filePath: '/A/Music/Beyond/乐与怒/01 海阔天空.flac',
        title: '海阔天空',
        artist: 'Beyond',
        album: '乐与怒',
        durationMs: 320000,
      ),
      _song(
        id: 2,
        filePath: '/A/Music/Adele/25/01 Hello.flac',
        title: 'Hello',
        artist: 'Adele',
        album: '25',
        durationMs: 295000,
      ),
    ];

    // 目标设备：iPhone 侧导出的平铺目录 + m4a/mp3 容器，时长各差 1 秒。
    final target = [
      _song(
        id: 11,
        filePath: '/B/iPhone/Beyond - 乐与怒 - 01 海阔天空.m4a',
        title: '海阔天空',
        artist: 'Beyond',
        album: '乐与怒',
        durationMs: 321000,
      ),
      _song(
        id: 12,
        filePath: '/B/iPhone/Adele - 25 - 01 Hello.mp3',
        title: 'Hello',
        artist: 'Adele',
        album: '25',
        durationMs: 294000,
      ),
    ];

    final report = matchM3uEntries(
      entries: parseM3u(buildM3u8(source)),
      library: target,
      baseDir: '/playlists',
      caseInsensitivePaths: false,
    );

    expect(report.songs.map((s) => s.id), [11, 12]);
    expect(report.matchedByMetadata, 2);
    expect(report.matchedByPath, 0);
    expect(report.skipped, 0);
  });

  test('归一化抹平大小写、空白与标点差异', () {
    expect(normalizeMatchText('  Beyond  -  海阔天空！'), 'beyond - 海阔天空');
    expect(normalizeMatchText('AC/DC'), 'ac/dc');
    expect(normalizeMatchText(null), '');
  });
}
