import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  /// 浅色主题。seed 由调用方解析后传入（默认石墨灰见 core 层
  /// [AccentColor.graphite]）；不再内置固定 seed。
  static ThemeData light({required Color seed}) =>
      _build(ColorScheme.fromSeed(seedColor: seed));

  /// 深色主题。seed 与 [light] 同源（同一 resolved seed 传两处），
  /// 明暗差异由 `ColorScheme.fromSeed(brightness: dark)` 表达。
  static ThemeData dark({required Color seed}) => _build(
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark),
  );

  /// 真·无彩色（monochrome）主题：石墨灰默认用它，**不走 [ColorScheme.fromSeed]**。
  ///
  /// 为什么灰 seed 不能走 fromSeed：fromSeed 固定按 seed 的 HCT 色相派生整套路子
  /// 并人为分配彩度（primary≈36、连 neutral 表面也≈6-8），输出必然带该色相色偏；
  /// 而纯灰（R=G=B）的色相是病态/不稳定的——三通道差 1~2 就足以让解出的色相
  /// 跳到完全不同的方向（灰蓝/灰黄/灰绿…），不可控也得不到纯灰。见 [_monochromeScheme]。
  static ThemeData monochrome({required Brightness brightness}) =>
      _build(_monochromeScheme(brightness));

  /// 手工构造 R=G=B 灰阶 [ColorScheme]（graphite 用）。
  static ColorScheme _monochromeScheme(Brightness brightness) {
    Color g(int v) => Color.fromARGB(255, v, v, v);
    final bool dark = brightness == Brightness.dark;

    // 明暗两套灰阶（数值对齐 M3 neutral 的大致 tone，全等 RGB 保证零色相）。
    final int surface = dark ? 0x14 : 0xF7;
    final int surfaceLowest = dark ? 0x0D : 0xFF;
    final int surfaceLow = dark ? 0x1A : 0xF5;
    final int surfaceContainer = dark ? 0x1F : 0xF0;
    final int surfaceHigh = dark ? 0x2A : 0xEB;
    final int surfaceHighest = dark ? 0x36 : 0xE6;
    final int onSurface = dark ? 0xE0 : 0x1A;
    final int onSurfaceVariant = dark ? 0xC4 : 0x4A;
    // 强调灰（选中/激活/高亮仍走 primary 语义，只是无彩色）。
    final int primary = dark ? 0xC4 : 0x5A;
    final int onPrimary = dark ? 0x2A : 0xFF;
    final int primaryContainer = dark ? 0x3D : 0xE6;
    final int onPrimaryContainer = dark ? 0xE0 : 0x1A;
    final int secondary = dark ? 0xB3 : 0x6E;
    final int onSecondary = dark ? 0x2A : 0xFF;
    final int secondaryContainer = dark ? 0x3D : 0xE6;
    final int onSecondaryContainer = dark ? 0xE0 : 0x1A;
    final int tertiary = dark ? 0xA6 : 0x80;
    final int onTertiary = dark ? 0x2A : 0xFF;
    final int tertiaryContainer = dark ? 0x44 : 0xF0;
    final int onTertiaryContainer = dark ? 0xE0 : 0x1A;
    final int outline = dark ? 0x8F : 0x74;
    final int outlineVariant = dark ? 0x4A : 0xC4;
    final int inverseSurface = dark ? 0xE0 : 0x2E;
    final int onInverseSurface = dark ? 0x14 : 0xF5;
    final int inversePrimary = dark ? 0x5A : 0xC9;
    // error 家族保留 M3 语义红（明暗各自一套），不随无彩色化。
    final Color error = dark
        ? const Color(0xFFF2B8B5)
        : const Color(0xFFB3261E);
    final Color onError = dark
        ? const Color(0xFF601410)
        : const Color(0xFFFFFFFF);
    final Color errorContainer = dark
        ? const Color(0xFF8C1D18)
        : const Color(0xFFF9DEDC);
    final Color onErrorContainer = dark
        ? const Color(0xFFF9DEDC)
        : const Color(0xFF410E0B);

    return ColorScheme(
      brightness: brightness,
      primary: g(primary),
      onPrimary: g(onPrimary),
      primaryContainer: g(primaryContainer),
      onPrimaryContainer: g(onPrimaryContainer),
      secondary: g(secondary),
      onSecondary: g(onSecondary),
      secondaryContainer: g(secondaryContainer),
      onSecondaryContainer: g(onSecondaryContainer),
      tertiary: g(tertiary),
      onTertiary: g(onTertiary),
      tertiaryContainer: g(tertiaryContainer),
      onTertiaryContainer: g(onTertiaryContainer),
      error: error,
      onError: onError,
      errorContainer: errorContainer,
      onErrorContainer: onErrorContainer,
      surface: g(surface),
      onSurface: g(onSurface),
      onSurfaceVariant: g(onSurfaceVariant),
      surfaceContainerLowest: g(surfaceLowest),
      surfaceContainerLow: g(surfaceLow),
      surfaceContainer: g(surfaceContainer),
      surfaceContainerHigh: g(surfaceHigh),
      surfaceContainerHighest: g(surfaceHighest),
      surfaceDim: g(dark ? 0x10 : 0xDE),
      surfaceBright: g(dark ? 0x2E : 0xFD),
      outline: g(outline),
      outlineVariant: g(outlineVariant),
      shadow: Colors.black,
      scrim: Colors.black,
      surfaceTint: Colors.transparent,
      inverseSurface: g(inverseSurface),
      onInverseSurface: g(onInverseSurface),
      inversePrimary: g(inversePrimary),
    );
  }

  static ThemeData _build(ColorScheme scheme) {
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        // 内容滚到 AppBar 下方时，M3 默认会把背景色切到 surfaceContainer 并升高
        // elevation；这里固定背景色并禁用 scrolledUnder 抬高，避免滚动时 AppBar 变色。
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
      ),
      // 弹出菜单统一大圆角（M3 默认仅 4，偏方像 M2）；明暗两套一致。
      popupMenuTheme: PopupMenuThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
