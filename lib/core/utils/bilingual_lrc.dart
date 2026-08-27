/// 「原文 + 翻译」同行双语 .lrc 的自动拆分工具。
///
/// 某些来源（如 krc 转出的 lrc）把「日文原文 中文翻译」写在同一行、共用一个
/// 时间戳，例如：
///
/// ```
/// [00:13.45]あの日1度だけと誓い合った秘め事は 那天我们唯一一次立下誓言所隐藏的秘密
/// ```
///
/// flutter_lyric 的翻译副行需要两条独立时间轴（主歌词 + translationLyric），
/// 本工具把这种同行双语拆成两段文本。
library;

/// 平假名/片假名（含长音符号「ー」U+30FC）。
final RegExp _kana = RegExp(r'[\u3040-\u30ff]');

/// 连续 CJK 汉字串（中日韩统一表意文字；日文汉字也在此区间，如「幾億」）。
final RegExp _hanziRun = RegExp(r'[\u4e00-\u9fff]{2,}');

/// 中文标点（翻译前导的引号/括号等，切分时归入翻译）。
final RegExp _cnPunct = RegExp(
  r'[\u300C\u300D\u300E\u300F\uFF08\uFF09\u3010\u3011\u3001\u3002'
  r'\uFF01\uFF1F\u2026\u2018\u2019\u201C\u201D\u00B7]',
);

/// Unicode 空白（含全角空格 U+3000、thin space U+2009 等）。
///
/// 原文与翻译之间通常以空白分隔；而日文原文句尾的汉字名词前是假名助词
/// （如「の所持量」「う督促状」），据此可排除误判。
final RegExp _blank = RegExp(
  r'[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]',
);

/// 「空白 + 连续 ≥2 汉字段」：翻译片段内部出现该结构，说明翻译起点选得
/// 太早（起点后面还有别的汉字段），真正的一整段翻译应在更靠后。
final RegExp _blankThenHanzi = RegExp(
  r'[\u0009-\u000D\u0020\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000][\u4e00-\u9fff]{2,}',
);

/// 行首时间戳/标签：`[00:13.45]` 或 `[ti:Even if..]`。
final RegExp _lineHeader = RegExp(r'^\[([^\[\]]*)\]\s*(.*)$');

/// 时间戳判定：`[数字:...]`（标签首字符是非数字，如 t/o/a）。
final RegExp _timestampTag = RegExp(r'^\d');

/// 单行内容（去掉 `[时间戳]` 后的文本）拆成「原文 + 翻译」。
///
/// 策略：找第一个「连续 ≥2 个 CJK 汉字、且自其起到行尾不含假名」的片段，
/// 其起点即翻译起点。翻译是中文（可含少量英文/标点），原文是日文——原文即使
/// 有连续汉字（如「幾億」「残酷」）也一定带假名后缀，因此不满足条件。
/// 翻译若以中文左引号（如「『）开头，该标点会一并归入翻译。
/// 找不到这样的片段 → 整行视为无翻译。
({String main, String translation}) splitBilingualLine(String content) {
  for (final m in _hanziRun.allMatches(content)) {
    // 翻译起点后（含后续）不得再有假名——翻译是中文。
    if (_kana.hasMatch(content.substring(m.start))) continue;

    // 切分点前移：把紧邻翻译的中文标点（左引号等）归入翻译。
    var start = m.start;
    while (start > 0 && _cnPunct.hasMatch(content[start - 1])) {
      start--;
    }
    // 翻译起点前必须是行首或空白（原文/翻译通常以空格分隔）；否则是日文
    // 原文句尾的汉字名词（如「の所持量」「う督促状」），并非翻译。
    if (start > 0 && !_blank.hasMatch(content[start - 1])) continue;

    final translation = content.substring(start);
    // 翻译片段内部不得再出现「空白 + 汉字段」：那说明起点选得太早（如
    // 「快感」后面还有「体感即是快感」），真正的翻译是一整段连续中文。
    if (_blankThenHanzi.hasMatch(translation)) continue;

    // 翻译起点在行首：整行即中文主歌词（如中文歌），无原文可拆。
    if (start == 0) {
      return (main: content.trimRight(), translation: '');
    }
    return (
      main: content.substring(0, start).trimRight(),
      translation: translation,
    );
  }
  return (main: content.trimRight(), translation: '');
}

/// 整首双语 .lrc 拆成「主歌词文本 + 翻译文本」两条时间轴。
///
/// - 标签行（[ti:]/[ar:] 等）保留在主歌词；
/// - 每行 `[mm:ss]原文 翻译` → 主歌词 `[mm:ss]原文` + 翻译 `[mm:ss]翻译`；
/// - 无翻译的行只进主歌词。
({String mainLyric, String translationLyric}) splitBilingualLrc(String lrc) {
  final main = StringBuffer();
  final trans = StringBuffer();
  for (final rawLine in lrc.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final header = _lineHeader.firstMatch(line);
    if (header == null) {
      // 非时间戳/标签行，原样进主歌词。
      main.writeln(line);
      continue;
    }
    final tag = header.group(1)!;
    final content = header.group(2)!;
    if (!_timestampTag.hasMatch(tag)) {
      // 标签行（[ti:...] 等）。
      main.writeln(line);
      continue;
    }
    final split = splitBilingualLine(content);
    main.writeln('[$tag]${split.main}');
    if (split.translation.isNotEmpty) {
      trans.writeln('[$tag]${split.translation}');
    }
  }
  return (mainLyric: main.toString(), translationLyric: trans.toString());
}
