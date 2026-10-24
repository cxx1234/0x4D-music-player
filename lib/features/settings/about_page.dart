import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/services/service_locator.dart';
import '../../l10n/l10n.dart';
import '../../widgets/detail_top_bar.dart';

/// 关于页：应用信息 + 开源许可 + 项目主页。
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  /// 开源项目主页。
  static const String repoUrl = 'https://github.com/cxx1234/0x4D-music-player';

  /// 复制项目主页链接到剪贴板。
  void _copyRepoUrl(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: repoUrl));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.aboutLinkCopied)));
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
    final l10n = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    // 版本号唯一来源：启动时由 package_info_plus 读取 pubspec.yaml 并缓存于
    // ServiceLocator.appVersion（读取失败时显示 …）。
    final version = ServiceLocator.appVersion ?? '…';

    return Scaffold(
      appBar: DetailTopBar(title: l10n.aboutTitle),
      // 项目约定：含 ListTile/InkWell 的滚动区外包透明 Material + Clip.hardEdge。
      body: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.hardEdge,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          children: [
            const SizedBox(height: 24),
            Center(
              // 明暗两套 logo:深色主题用白字版,浅色主题用深字版。
              // 两张图均为透明背景,可直接贴合页面底色。
              child: Image.asset(
                theme.brightness == Brightness.dark
                    ? 'assets/icon/0x4D_no_background.png'
                    : 'assets/icon/0x4D_no_background_b.png',
                width: 96,
                height: 96,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
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
            Center(child: Text(l10n.aboutVersion(version), style: muted)),
            const SizedBox(height: 8),
            Center(child: Text(l10n.aboutTagline, style: muted)),
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
                    title: _buildOptionText(
                      theme,
                      l10n.aboutLicenses,
                      'MIT License',
                    ),
                    subtitle: null,
                  ),
                  ListTile(
                    minVerticalPadding: 16,
                    leading: const Icon(Icons.link),
                    title: _buildOptionText(
                      theme,
                      l10n.aboutProjectHome,
                      repoUrl,
                    ),
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
