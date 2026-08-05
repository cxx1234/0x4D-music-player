import 'package:flutter/material.dart';

import '../../widgets/page_toolbar.dart';

class SearchPage extends StatelessWidget {
  const SearchPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const PageToolbar(title: '搜索'),
        const Divider(height: 1),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('搜索', style: theme.textTheme.headlineSmall),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
