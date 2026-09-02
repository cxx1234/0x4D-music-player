import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/logger.dart';

/// 桥接 macOS 系统强调色（原生 `SystemAccentPlugin.swift`）。
///
/// 职责：
/// - 启动 / 显式 [refresh] 时向原生查询当前系统强调色
///   （`NSColor.controlAccentColor`，即 系统设置 → 外观 → 强调色）；
/// - 原生在系统强调色变化时（强调色设置改动 / Multicolor 壁纸变化）主动推送
///   `accentChanged`，这里同步 [systemAccentNotifier]，实现「实时跟随」；
/// - 非 macOS / 通道不可用时 [systemAccentNotifier] 保持 null——由
///   [AccentColor.seedColor] 回退默认石墨灰，绝不抛错、不阻塞启动。
///
/// 仅 macOS 创建（[ServiceLocator] 按 `Platform.isMacOS` 判断），仿
/// [MenuService] 的 macOS-only 通道模式。
class SystemAccentService {
  SystemAccentService._();

  static const _channel = MethodChannel('com.jerryc.txvziwm/system_accent');

  /// 当前系统强调色；null = 未知 / 不可用（非 macOS、尚未读到、出错）。
  final systemAccentNotifier = ValueNotifier<Color?>(null);

  bool _disposed = false;

  /// 创建实例、注册通道 handler 并触发首次读取（失败不抛）。
  factory SystemAccentService.attach() {
    final service = SystemAccentService._();
    service._init();
    return service;
  }

  void _init() {
    if (!Platform.isMacOS) return; // 其他平台无原生实现。
    _channel.setMethodCallHandler(_handleCall);
    unawaited(refresh());
  }

  /// 原生 → Dart 推送：系统强调色变化。
  Future<Object?> _handleCall(MethodCall call) async {
    if (call.method == 'accentChanged') {
      final color = accentFromRgb(call.arguments);
      if (color != null) systemAccentNotifier.value = color;
    }
    return null;
  }

  /// 主动向原生查询一次当前系统强调色并更新 [systemAccentNotifier]。
  Future<void> refresh() async {
    if (!Platform.isMacOS || _disposed) return;
    try {
      final rgb = await _channel.invokeMethod<Object?>('getAccent');
      final color = accentFromRgb(rgb);
      if (color != null) systemAccentNotifier.value = color;
    } catch (e) {
      AppLogger.warning('App', 'Failed to read system accent color', e);
    }
  }

  void dispose() {
    _disposed = true;
    systemAccentNotifier.dispose();
  }
}

/// `[r, g, b]`（0-255）→ [Color]；非法 / 非 List / 越界防御，返回 null。
Color? accentFromRgb(Object? rgb) {
  if (rgb is! List) return null;
  if (rgb.length < 3) return null;
  final r = rgb[0];
  final g = rgb[1];
  final b = rgb[2];
  if (r is! num || g is! num || b is! num) return null;
  return Color.fromARGB(
    255,
    r.toInt().clamp(0, 255),
    g.toInt().clamp(0, 255),
    b.toInt().clamp(0, 255),
  );
}
