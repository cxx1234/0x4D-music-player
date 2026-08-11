import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 启动失败时显示的全屏错误页,提供重试与复制详情。
class StartupErrorPage extends StatelessWidget {
  const StartupErrorPage({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.error_outline, size: 48, color: scheme.error),
                const SizedBox(height: 16),
                Text(
                  '应用启动失败',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  '无法初始化应用服务，请重试。若持续失败，请复制错误详情并反馈。',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    error.toString(),
                    maxLines: 6,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: const Text('重试')),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: error.toString())),
                  child: const Text('复制错误详情'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
