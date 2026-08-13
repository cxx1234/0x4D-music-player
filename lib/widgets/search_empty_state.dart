import 'package:flutter/material.dart';

/// 搜索无结果的空状态（配合 `PageToolbar` 下的 `Expanded` 使用）。
class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({super.key, this.query, this.message});

  /// 搜索关键词（可空，用于展示"没有找到与『xx』相关的结果"）。
  final String? query;

  /// 自定义提示文案（默认按 [query] 生成）。
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text =
        message ??
        (query == null || query!.trim().isEmpty
            ? '没有找到相关内容'
            : '没有找到与「${query!.trim()}」相关的内容');

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(text, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            '换个关键词试试',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
