import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/detail_top_bar.dart';

/// 关于页：应用信息 + 开源许可 + 项目主页。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 版本号（暂时硬编码；后续如引入 package_info_plus 可自动读取）。
  static const String version = '0.2.2';

  /// 开源项目主页。
  static const String repoUrl = 'https://github.com/cxx1234/0x4D-music-player';

  /// 复制项目主页链接到剪贴板。
  void _copyRepoUrl(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: repoUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制项目链接')));
  }

  /// 选项副标题样式：比 bodySmall 再小一档、偏灰（与设置页/SongTile 一致）。
  TextStyle _subtitleStyle(ThemeData theme) => theme.textTheme.bodySmall!
      .copyWith(fontSize: 11, color: theme.colorScheme.onSurfaceVariant);

  /// 选项行的标题+副标题组合块（两行整体垂直居中，与设置页一致）。
  Widget _buildOptionText(ThemeData theme, String title, String subtitle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _subtitleStyle(theme),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: DetailTopBar(title: '关于'),
      // 项目约定：含 ListTile/InkWell 的滚动区外包透明 Material + Clip.hardEdge。
      body: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.hardEdge,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const SizedBox(height: 24),
            Center(
              child: Icon(
                Icons.music_note_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '0x4D Music Player',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('版本 $version', style: muted)),
            const SizedBox(height: 8),
            Center(child: Text('本地音乐播放器', style: muted)),
            const SizedBox(height: 32),
            Card(
              margin: EdgeInsets.zero,
              elevation: 0,
              color: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    minVerticalPadding: 16,
                    leading: const Icon(Icons.code),
                    title: _buildOptionText(theme, '开源许可', 'MIT License'),
                    subtitle: null,
                  ),
                  ListTile(
                    minVerticalPadding: 16,
                    leading: const Icon(Icons.link),
                    title: _buildOptionText(theme, '项目主页', repoUrl),
                    subtitle: null,
                    trailing: const Icon(Icons.copy),
                    onTap: () => _copyRepoUrl(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
