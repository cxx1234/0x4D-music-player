import 'package:flutter/material.dart';

import '../../widgets/page_toolbar.dart';

/// 设置页。
///
/// TODO(日志)：在此页接入「日志查看」入口 —— 在 PageToolbar 下方的设置
/// 列表中添加一个「日志」列表项，点击跳转：
/// `Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LogPage()));`
/// （页面实现见 `lib/features/settings/log_page.dart`，当前尚未接入导航。）
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const PageToolbar(title: '设置'),
        const Divider(height: 1),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text('设置', style: theme.textTheme.headlineSmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
