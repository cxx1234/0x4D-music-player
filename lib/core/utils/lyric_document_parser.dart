import 'package:flutter_lyric/flutter_lyric.dart';

import 'bilingual_lrc.dart';

/// 把歌词文本解析成 [LyricDocument]。
///
/// - LRC：先经 [splitBilingualLrc] 拆出主歌词 + 翻译两条时间轴；
///   [includeTranslation] 只决定是否带上副行。
/// - QRC / YRC 等词级时间轴：交给 flutter_lyric 自动探测，避免被误当成
///   纯文本压成一行静态歌词。
/// - 完全无时间轴：降级为单行静态歌词。
///
/// [hasTranslation] 是内容事实，与翻译开关/界面语言无关。
({LyricDocument document, bool hasTranslation}) parseLyricContent(
  String content, {
  bool includeTranslation = true,
}) {
  final isLrc = RegExp(r'^\[\d{1,}:\d{2}', multiLine: true).hasMatch(content);
  if (isLrc) {
    final split = splitBilingualLrc(content);
    final hasTranslation = split.translationLyric.isNotEmpty;
    return (
      document: LyricDocument.parse(
        split.mainLyric,
        translation: includeTranslation && hasTranslation
            ? split.translationLyric
            : null,
      ),
      hasTranslation: hasTranslation,
    );
  }

  final timed = LyricDocument.parse(content);
  if (timed.lines.isNotEmpty) {
    return (document: timed, hasTranslation: false);
  }

  return (
    document: LyricDocument(
      lines: [LyricLine(start: Duration.zero, text: content.trim())],
    ),
    hasTranslation: false,
  );
}
