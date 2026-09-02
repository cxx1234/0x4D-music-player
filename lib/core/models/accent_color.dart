import 'package:flutter/material.dart';

/// 石墨灰 seed（默认主题色）：纯中性经典中灰 `#616161`（Material grey 700，
/// R=G=B 零色相 → 不偏黄也不偏蓝）。放 core 层供 [AccentColor] 使用，
/// 避免 core → app 反向依赖（theme.dart 不设默认 seed，统一由此解析）。
const Color kGraphiteSeed = Color(0xFF616161);

/// 界面强调色（主题 seed 色板 + 跟随系统）。
///
/// 与 [LyricTextSize] / [SongSortOrder] 同为「枚举自带 UI 文案放 core 层」的
/// 既有模式：core 层的 [SettingsService] 需要存取该类型（主题色写盘持久化），
/// 因此不放在 features/settings（避免 core → features 反向依赖）。
///
/// 持久化存 [name]：`'system'` / `'graphite'` / `'deepPurple'` …；
/// 未知/缺省一律回退 [AccentColor.graphite]（默认石墨灰）。
enum AccentColor {
  /// 跟随系统强调色（无固定 seed，见 [seedColor]）。
  system('跟随系统', null),

  /// 石墨灰（默认，纯中性）。
  graphite('石墨灰', kGraphiteSeed),

  /// 深紫。
  deepPurple('深紫', Colors.deepPurple),

  /// 靛蓝。
  indigo('靛蓝', Colors.indigo),

  /// 蓝。
  blue('蓝', Colors.blue),

  /// 青。
  cyan('青', Colors.cyan),

  /// 绿。
  green('绿', Colors.green),

  /// 橙。
  orange('橙', Colors.orange),

  /// 红。
  red('红', Colors.red),

  /// 粉。
  pink('粉', Colors.pink),

  /// 蓝灰。
  blueGrey('蓝灰', Colors.blueGrey);

  const AccentColor(this.label, this.seed);

  /// 色板圆点 / tooltip 用的中文标签。
  final String label;

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
