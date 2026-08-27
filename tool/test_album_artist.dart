/// 实际验证本地 fork 补强后的 audio_metadata_reader（feat/album-artist）。
///
/// 读取 test/music/ 下的真实音频文件，重点验证：
///   - 通用视图 AudioMetadata.albumArtist（补丁新增，此前丢失）
///   - 格式专属字段（MP3 bandOrOrchestra / FLAC albumArtist / M4A albumArtist）
///   - 歌词解析（lyrics 是否取到）
///
/// 运行：dart run tool/test_album_artist.dart
library;

import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';

void main() {
  final dir = Directory('test/music');
  if (!dir.existsSync()) {
    stderr.writeln('❌ test/music/ 不存在，请确认测试音频已就位');
    exit(1);
  }

  final files = dir.listSync().whereType<File>().where((f) {
    final ext = f.path.toLowerCase().split('.').last;
    return const ['.mp3', '.flac', '.m4a'].contains('.$ext');
  }).toList()..sort((a, b) => a.path.compareTo(b.path));

  if (files.isEmpty) {
    stderr.writeln('❌ test/music/ 下没有 mp3/flac/m4a 文件');
    exit(1);
  }

  var ok = 0;
  var fail = 0;

  for (final f in files) {
    final name = f.uri.pathSegments.last;
    final ext = name.toLowerCase().split('.').last;
    print('\n═══════════════ $name ═══════════════');

    try {
      final m = readMetadata(f);

      print('  [通用视图 AudioMetadata]');
      print('    title       : ${m.title}');
      print('    artist      : ${m.artist}');
      print('    album       : ${m.album}');
      print('    albumArtist : ${m.albumArtist ?? '(空)'}');
      print(
        '    lyrics?     : ${m.lyrics != null ? 'YES (${m.lyrics!.length} 字符)' : 'NO'}',
      );

      final aaOk = m.albumArtist != null && m.albumArtist!.trim().isNotEmpty;
      print(
        aaOk
            ? '  ✅ albumArtist 解析成功：${m.albumArtist}'
            : '  ⚠️  albumArtist 为空（该文件可能本来就没写 albumArtist）',
      );

      if (m.lyrics != null && m.lyrics!.length > 160) {
        final head = m.lyrics!.substring(0, 160).replaceAll('\n', ' ⏎ ');
        print('    歌词头部: $head…');
      }

      // 格式专属字段（readAllMetadata 全量解析）
      final all = readAllMetadata(f, getImage: false);
      print('  [格式专属]');
      String? fmtAlbumArtist;
      switch (ext) {
        case 'mp3':
          final mm = all as Mp3Metadata;
          fmtAlbumArtist = mm.albumArtist;
          print('    Mp3Metadata.bandOrOrchestra : ${mm.bandOrOrchestra}');
          print('    Mp3Metadata.albumArtist     : ${mm.albumArtist}');
          print('    Mp3Metadata.lyric?          : ${mm.lyric != null}');
        case 'flac':
          final vm = all as VorbisMetadata;
          fmtAlbumArtist = vm.albumArtist.isNotEmpty
              ? vm.albumArtist.first
              : null;
          print('    VorbisMetadata.albumArtist  : ${vm.albumArtist}');
          print('    VorbisMetadata.lyric?       : ${vm.lyric != null}');
        case 'm4a':
          final m4 = all as Mp4Metadata;
          fmtAlbumArtist = m4.albumArtist;
          print('    Mp4Metadata.albumArtist     : ${m4.albumArtist}');
          print('    Mp4Metadata.lyrics?         : ${m4.lyrics != null}');
      }
      print(
        '    通用视图 与 格式专属 一致?      : '
        '${m.albumArtist == fmtAlbumArtist} (${m.albumArtist} vs $fmtAlbumArtist)',
      );

      ok++;
    } catch (e) {
      print('  ❌ 解析失败: $e');
      fail++;
    }
  }

  print('\n═══════════════ 结果汇总 ═══════════════');
  print('  成功: $ok  失败: $fail');
  if (fail > 0) exit(1);
}
