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

/// 拉丁字母（英文原文行，如 Michael Jackson 的歌）。
final RegExp _latin = RegExp(r'[a-zA-Z]');

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
    // 「翻译内部不得再出现 空白+汉字段」的防误切，仅对「原文为纯中文」的行
    // 有意义（如「体感 即 快感 体感即是快感」中的「快感」）。日文原文（含
    // 假名）或英文原文（含拉丁字母）的翻译内部常带空格分段（如「夜风拂过
    // 暗夜飘摇 …」「她走进来所踩的步伐 那时那刻我就察觉」），起点应停在
    // 第一个翻译段，不能推到最后一个汉字段。
    final mainPart = content.substring(0, start);
    final mainIsPureChinese =
        !_kana.hasMatch(mainPart) && !_latin.hasMatch(mainPart);
    if (mainIsPureChinese && _blankThenHanzi.hasMatch(translation)) continue;

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

/// 解析后的一行：原始文本（trim 后）+ 时间戳标签 + 内容 + 是否时间戳行。
typedef _LrcEntry = ({
  String raw,
  String tag,
  String content,
  bool isTimestamp,
});

/// 整首双语 .lrc 拆成「主歌词文本 + 翻译文本」两条时间轴。
///
/// 优先识别「两段式 LRC」（QQ 音乐等来源）：前半段原文、后半段翻译各带
/// 一条完整时间轴（翻译段从同一首个时间戳重新开始）。命中时按段整体分配，
/// **不再做单行拆分**（否则中文翻译行会被再次拆开而撕裂）。
///
/// 非两段式时走单行拆分：
/// - 标签行（[ti:]/[ar:] 等）保留在主歌词；
/// - 每行 `[mm:ss]原文 翻译` → 主歌词 `[mm:ss]原文` + 翻译 `[mm:ss]翻译`；
/// - 无翻译的行只进主歌词。
({String mainLyric, String translationLyric}) splitBilingualLrc(String lrc) {
  final entries = <_LrcEntry>[];
  for (final rawLine in lrc.split('\n')) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;

    final header = _lineHeader.firstMatch(line);
    if (header == null) {
      // 非时间戳/标签行。
      entries.add((raw: line, tag: '', content: '', isTimestamp: false));
      continue;
    }
    final tag = header.group(1)!;
    final content = header.group(2)!;
    entries.add((
      raw: line,
      tag: tag,
      content: content,
      isTimestamp: _timestampTag.hasMatch(tag),
    ));
  }

  // 两段式：翻译段从「首个时间戳」重新开始（该时间戳在文件后部第二次出现）。
  final twoPass = _trySplitTwoPass(entries);
  if (twoPass != null) return twoPass;

  // 单行内嵌双语：逐行拆分。
  final main = StringBuffer();
  final trans = StringBuffer();
  for (final e in entries) {
    if (!e.isTimestamp) {
      // 标签行/普通行：原样进主歌词。
      main.writeln(e.raw);
      continue;
    }
    final split = splitBilingualLine(e.content);
    main.writeln('[${e.tag}]${split.main}');
    if (split.translation.isNotEmpty) {
      trans.writeln('[${e.tag}]${split.translation}');
    }
  }
  return (mainLyric: main.toString(), translationLyric: trans.toString());
}

/// 尝试识别「两段式 LRC」并拆分；不是两段式返回 null。
///
/// 两段式特征：文件后部再次出现「首个时间戳」（翻译段从同一起点重新
/// 开始）。命中时 [0, splitAt) 为主歌词、[splitAt, end) 为翻译时间轴。
({String mainLyric, String translationLyric})? _trySplitTwoPass(
  List<_LrcEntry> entries,
) {
  String? firstTag;
  var foundFirst = false;
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    if (!e.isTimestamp) continue;
    if (!foundFirst) {
      firstTag = e.tag;
      foundFirst = true;
      continue;
    }
    if (e.tag == firstTag) {
      // 翻译段至少要有几行时间戳，防「单行重复」噪声误判。
      final transCount = entries.skip(i).where((x) => x.isTimestamp).length;
      if (transCount >= 3) {
        return _splitTwoPass(entries, i);
      }
      break;
    }
  }
  return null;
}

/// 两段式拆分：前半段 → 主歌词（含标签），后半段 → 翻译时间轴
/// （跳过标签行与空内容行，不再做单行拆分）。
({String mainLyric, String translationLyric}) _splitTwoPass(
  List<_LrcEntry> entries,
  int splitAt,
) {
  final main = StringBuffer();
  final trans = StringBuffer();
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    if (i < splitAt) {
      main.writeln(e.raw);
      continue;
    }
    // 翻译段：跳过标签行与空内容行。
    if (!e.isTimestamp || e.content.trim().isEmpty) continue;
    trans.writeln(e.raw);
  }
  return (mainLyric: main.toString(), translationLyric: trans.toString());
}
