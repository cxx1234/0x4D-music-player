import 'package:flutter/material.dart';
import 'package:metadata_god/metadata_god.dart';

import 'theme.dart';
import 'router.dart';
import '../core/services/service_locator.dart';
import '../features/shell/shell_page.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    ServiceLocator.initialize().then((_) async {
      try {
        await MetadataGod.initialize();
        debugPrint('MetadataGod initialized successfully');
      } catch (e) {
        debugPrint('MetadataGod initialization failed: $e');
      }
      if (mounted) {
        setState(() => _initialized = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Music',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: ShellPage(isInitialized: _initialized),
      onGenerateRoute: AppRouter.generateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
