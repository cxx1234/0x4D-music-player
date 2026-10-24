import 'package:flutter/material.dart';

/// 石墨灰 seed（默认主题色）：纯中性经典中灰 `#616161`（Material grey 700，
/// R=G=B 零色相 → 不偏黄也不偏蓝）。放 core 层供 [AccentColor] 使用，
/// 避免 core → app 反向依赖（theme.dart 不设默认 seed，统一由此解析）。
const Color kGraphiteSeed = Color(0xFF616161);

/// 界面强调色（主题 seed 色板 + 跟随系统）。
///
/// 持久化存 [name]：`'system'` / `'graphite'` / `'deepPurple'` …；
/// 未知/缺省一律回退 [AccentColor.graphite]（默认石墨灰）。
/// 展示文案见 `lib/l10n/enum_labels.dart`，core 层不再持有 UI 文案。
enum AccentColor {
  /// 跟随系统强调色（无固定 seed，见 [seedColor]）。
  system(null),

  /// 石墨灰（默认，纯中性）。
  graphite(kGraphiteSeed),

  /// 深紫。
  deepPurple(Colors.deepPurple),

  /// 靛蓝。
  indigo(Colors.indigo),

  /// 蓝。
  blue(Colors.blue),

  /// 青。
  cyan(Colors.cyan),

  /// 绿。
  green(Colors.green),

  /// 橙。
  orange(Colors.orange),

  /// 红。
  red(Colors.red),

  /// 粉。
  pink(Colors.pink),

  /// 蓝灰。
  blueGrey(Colors.blueGrey);

  const AccentColor(this.seed);

  /// 该预设项的 seed 色；仅 [AccentColor.system] 为 null（无固定色）。
  final Color? seed;

  /// 是否「跟随系统强调色」。
  bool get followsSystem => this == AccentColor.system;

  /// 解析用作主题 seed 的具体颜色。
  ///
  /// - 预设项：返回自身固定 [seed]；
  /// - [AccentColor.system]：**直用**传入的系统强调色 [systemColor]
  ///   （M3 `ColorScheme.fromSeed` 接受任意 seed、自动派生 tonal palette，
  ///   无需映射到预设）；拿不到系统色（非 macOS / 尚未读到 / 出错）时
  ///   回退默认石墨灰，保证始终有可用配色。
  Color seedColor([Color? systemColor]) {
    if (this == AccentColor.system) {
      return systemColor ?? AccentColor.graphite.seed!;
    }
    return seed!;
  }

  /// 从持久化的枚举名恢复；未知/空值回退默认 [AccentColor.graphite]。
  static AccentColor fromName(String? name) {
    if (name == null) return AccentColor.graphite;
    return AccentColor.values.firstWhere(
      (e) => e.name == name,
      orElse: () => AccentColor.graphite,
    );
  }
}
