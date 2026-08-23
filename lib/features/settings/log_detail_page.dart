import 'package:flutter/material.dart';

import '../../widgets/detail_top_bar.dart';
import 'log_page.dart';

/// 单条日志的详情页：完整时间戳 + 级别 + tag + 消息 + 异常/堆栈附加行。
class LogDetailPage extends StatelessWidget {
  const LogDetailPage({super.key, required this.entry});

  final LogEntry entry;

  String get _fullTimestamp {
    final t = entry.timestamp;
    String two(int n) => n.toString().padLeft(2, '0');
    String three(int n) => n.toString().padLeft(3, '0');
    return '${t.year}-${two(t.month)}-${two(t.day)} '
        '${two(t.hour)}:${two(t.minute)}:${two(t.second)}.${three(t.millisecond)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = logLevelColor(theme, entry.level);

    return Scaffold(
      appBar: DetailTopBar(title: '日志详情'),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                entry.level,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Text(entry.tag, style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _fullTimestamp,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(entry.message, style: theme.textTheme.titleMedium),
          if (entry.detailLines.isNotEmpty) ...[
            const SizedBox(height: 16),
            // 异常/堆栈区：等宽字体,便于阅读调用链。
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                entry.detailLines.join('\n'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
