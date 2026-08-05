import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        // 内容滚到 AppBar 下方时，M3 默认会把背景色切到 surfaceContainer 并升高
        // elevation；这里固定背景色并禁用 scrolledUnder 抬高，避免滚动时 AppBar 变色。
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
      ),
    );
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
      ),
    );
  }
}
