import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

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
    final l10n = context.l10n;
    final text =
        message ??
        (query == null || query!.trim().isEmpty
            ? l10n.searchEmptyTitle
            : l10n.searchEmptyQuery(query!.trim()));

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(text, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            l10n.searchEmptyHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
