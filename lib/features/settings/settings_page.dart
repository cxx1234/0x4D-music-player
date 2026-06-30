import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            '设置',
            style: theme.textTheme.headlineSmall,
          ),
        ],
      ),
    );
  }
}
