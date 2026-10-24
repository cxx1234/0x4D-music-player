import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 护栏：界面文案只能出现在 `lib/l10n/` 的 ARB / 生成代码里。
///
/// 允许中文出现在注释与文档中；这里只检查字符串字面量。新增文案时把 key 写进
/// `app_en.arb` / `app_zh.arb`，再用 `context.l10n` 或服务的 l10n provider 取用。
void main() {
  test('lib/ 除 l10n 外没有中文字面量', () {
    final cjk = RegExp(r'[\u4e00-\u9fff]');
    final literal = RegExp(r'''(['"])((?:\\.|(?!\1).)*?)\1''');
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.startsWith('lib/l10n/') || path.endsWith('.g.dart')) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        // 注释里的中文是约定（docs / 代码注释用中文），不参与检查。
        if (line.trimLeft().startsWith('//')) continue;
        for (final match in literal.allMatches(line)) {
          if (cjk.hasMatch(match.group(2)!)) {
            offenders.add('$path:${i + 1}: ${match.group(2)}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          '界面文案请写进 lib/l10n/app_en.arb + app_zh.arb，'
          '再用 context.l10n / AppLocalizations 取用：\n${offenders.join('\n')}',
    );
  });
}
