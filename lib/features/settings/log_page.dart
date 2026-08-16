import 'dart:io';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/utils/logger.dart';
import '../../widgets/detail_top_bar.dart';
import 'log_detail_page.dart';

/// 一条日志记录(对应日志文件中的一行日志 + 其后的异常/堆栈附加行)。
class LogEntry {
  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    required this.detailLines,
  });

  final DateTime timestamp;

  /// DEBUG / INFO / WARN / ERROR / FATAL(已去定宽填充)。
  final String level;
  final String tag;
  final String message;

  /// 日志正文之后的附加行(异常信息 / 调用堆栈等),可空。
  final List<String> detailLines;
}

/// 匹配一行正式日志：`yyyy-MM-dd HH:mm:ss.mmm [LEVEL] [tag] message`。
///
/// 级别是 5 字符定宽右对齐(如 `INFO ` 带尾随空格),因此 `]` 前允许空白。
final _entryPattern = RegExp(
  r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})\.(\d{3}) \[([A-Z]+)\s*\] \[(.+)\] (.*)$',
);

/// 把日志文件的行解析成 [LogEntry] 列表。
///
/// 以时间戳开头的行为一条新日志；其余非空行(异常/堆栈)归属到上一条。
List<LogEntry> parseLogLines(List<String> lines) {
  final entries = <LogEntry>[];
  LogEntry? current;
  for (final raw in lines) {
    final line = raw.replaceAll('\r', '');
    if (line.isEmpty) continue;
    final m = _entryPattern.firstMatch(line);
    if (m != null) {
      current = LogEntry(
        timestamp: DateTime(
          int.parse(m[1]!),
          int.parse(m[2]!),
          int.parse(m[3]!),
          int.parse(m[4]!),
          int.parse(m[5]!),
          int.parse(m[6]!),
          int.parse(m[7]!),
        ),
        level: m[8]!.trim(),
        tag: m[9]!.trim(),
        message: m[10]!,
        detailLines: <String>[],
      );
      entries.add(current);
    } else if (current != null) {
      current.detailLines.add(line);
    }
  }
  return entries;
}

/// 日志级别对应的强调色(仅 WARN/ERROR/FATAL 醒目,其余走 onSurfaceVariant)。
Color logLevelColor(ThemeData theme, String level) {
  final scheme = theme.colorScheme;
  switch (level) {
    case 'ERROR':
    case 'FATAL':
      return scheme.error;
    case 'WARN':
      return Colors.orange.shade700;
    default:
      return scheme.onSurfaceVariant;
  }
}

/// 日志查看页：读取 `{appDocDir}/logs/` 下的日志文件,按行展示。
/// 每行可点击进入 [LogDetailPage] 查看该条日志的完整内容。
///
/// TODO(日志)：本页尚未接入任何导航。接入方式 —— 在设置页
/// (`lib/features/settings/settings_page.dart`)添加「日志」入口：
/// `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogPage()));`
class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  List<String> _days = const []; // 可用日志日期(如 2026-08-11),按日期降序
  String? _selectedDay; // 当前选中的日期
  List<LogEntry> _entries = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final dir = await AppLogger.logDirectory();
      final files = <File>[];
      if (await dir.exists()) {
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          final name = p.basename(entity.path);
          if (name.startsWith('app-') && name.endsWith('.log')) {
            files.add(entity);
          }
        }
      }
      // 按文件名字典序(即日期)降序,最新在前。
      files.sort((a, b) => b.path.compareTo(a.path));

      final days = [
        for (final f in files)
          p.basename(f.path).substring(4, p.basename(f.path).length - 4),
      ];
      final selected = _selectedDay ?? (days.isNotEmpty ? days.first : null);

      var entries = <LogEntry>[];
      if (selected != null) {
        final dayFile = files.firstWhere(
          (f) => p.basename(f.path) == 'app-$selected.log',
          orElse: () => File(''),
        );
        if (await dayFile.exists()) {
          final content = await dayFile.readAsString();
          entries = parseLogLines(content.split('\n'));
        }
      }

      if (!mounted) return;
      setState(() {
        _days = days;
        _selectedDay = selected;
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      AppLogger.error('LogPage', 'Failed to load logs', e);
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _selectDay(String day) async {
    if (day == _selectedDay) return;
    setState(() {
      _selectedDay = day;
      _loading = true;
    });
    await _load();
  }

  void _openDetail(LogEntry entry) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => LogDetailPage(entry: entry)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailTopBar(
        title: '日志',
        actions: [
          if (_days.length > 1)
            PopupMenuButton<String>(
              tooltip: '选择日期',
              initialValue: _selectedDay,
              onSelected: _selectDay,
              itemBuilder: (context) => [
                for (final day in _days)
                  PopupMenuItem(value: day, child: Text(day)),
              ],
              icon: const Icon(Icons.calendar_month),
            ),
        ],
      ),
      body: _buildBody(Theme.of(context)),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.article_outlined,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text('暂无日志', style: theme.textTheme.bodyMedium),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  '当前为 Debug 构建,日志仅输出到控制台,不会写入本页。'
                  'Release/Profile 构建才会生成日志文件。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
    // 项目 UI 约定：有界滚动区含 InkWell 项必须外包透明 Material + Clip.hardEdge。
    return Material(
      type: MaterialType.transparency,
      clipBehavior: Clip.hardEdge,
      child: ListView.builder(
        itemCount: _entries.length,
        itemBuilder: (context, index) {
          final entry = _entries[index];
          return _LogTile(entry: entry, onTap: () => _openDetail(entry));
        },
      ),
    );
  }
}

/// 日志列表的一行：级别色点 + 时间 + 级别 + tag + 消息(单行)。
class _LogTile extends StatelessWidget {
  const _LogTile({required this.entry, required this.onTap});

  final LogEntry entry;
  final VoidCallback onTap;

  String get _timeText {
    final t = entry.timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = logLevelColor(theme, entry.level);
    final variant = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 级别色点
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _timeText,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: variant,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.level,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.tag,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: variant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: variant),
          ],
        ),
      ),
    );
  }
}
