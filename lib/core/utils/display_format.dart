/// 纯展示格式化：扩展名 / 文件大小 / 时长 / 码率 / 采样率。
///
/// 只做字符串拼装，不含本地化文案 —— 单位（B、KB、kbps、kHz）按行业习惯保留
/// 拉丁字母，与信息卡既有的 `96000 Hz` 一致。日期不在这里处理：需要本地化
/// 格式，用 `MaterialLocalizations`。
library;

/// 从文件名取扩展名的大写形式（`song.flac` → `FLAC`）；无扩展名返回空串。
String fileTypeLabel(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot < 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot + 1).toUpperCase();
}

/// 字节数 → 人类可读（B/KB/MB/GB）。
String formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}

/// 时长（毫秒）→ `m:ss` / `h:mm:ss`；空值或负数返回 null（调用方隐藏整行）。
String? formatDurationMs(int? milliseconds) {
  if (milliseconds == null || milliseconds < 0) return null;
  final totalSeconds = (milliseconds / 1000).round();
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final twoDigitSeconds = seconds.toString().padLeft(2, '0');
  if (hours == 0) return '$minutes:$twoDigitSeconds';
  final twoDigitMinutes = minutes.toString().padLeft(2, '0');
  return '$hours:$twoDigitMinutes:$twoDigitSeconds';
}

/// 码率（bit/s）→ `320 kbps` / `1.41 Mbps`；空值或非正数返回 null。
String? formatBitrate(int? bitsPerSecond) {
  if (bitsPerSecond == null || bitsPerSecond <= 0) return null;
  if (bitsPerSecond < 1000 * 1000) {
    return '${(bitsPerSecond / 1000).round()} kbps';
  }
  return '${(bitsPerSecond / (1000 * 1000)).toStringAsFixed(2)} Mbps';
}

/// 采样率（Hz）→ `44.1 kHz` / `96 kHz`；空值或非正数返回 null。
String? formatSampleRate(int? hertz) {
  if (hertz == null || hertz <= 0) return null;
  final kilohertz = hertz / 1000;
  final text = kilohertz == kilohertz.roundToDouble()
      ? kilohertz.toStringAsFixed(0)
      : kilohertz.toStringAsFixed(1);
  return '$text kHz';
}

/// 文件平均码率（bit/s）：`文件大小 × 8 ÷ 时长`。
///
/// 解析器给的 `bitrate` **不能直接展示**：FLAC 返回的是「位深 × 采样率」的
/// PCM 位率（16-bit / 44.1 kHz 恒为 705.6 kbps，与压缩后的体积无关），VBR
/// MP3 也只是某一帧的值 —— 见 `docs/Pitfalls.md` C17。只有算不出平均码率时
/// 才回退解析值。
int? averageBitrateBps({int? fileSize, int? durationMs, int? fallbackBps}) {
  if (fileSize != null &&
      fileSize > 0 &&
      durationMs != null &&
      durationMs > 0) {
    return (fileSize * 8 * 1000 / durationMs).round();
  }
  return (fallbackBps != null && fallbackBps > 0) ? fallbackBps : null;
}
