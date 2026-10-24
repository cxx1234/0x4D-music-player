import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/services/library_scanner_service.dart';
import 'package:txvziwm/features/library/library_page.dart';
import 'package:txvziwm/l10n/app_localizations.dart';

import 'helpers/l10n.dart';

void main() {
  group('scanResultText', () {
    late AppLocalizations zh;
    late AppLocalizations en;

    setUpAll(() async {
      zh = await loadL10n();
      en = await loadL10n(const Locale('en'));
    });

    ScanResult result({
      int added = 0,
      int updated = 0,
      int markedMissing = 0,
      int skipped = 0,
      int errors = 0,
      int purged = 0,
    }) {
      return ScanResult(
        added: added,
        updated: updated,
        markedMissing: markedMissing,
        skipped: skipped,
        errors: errors,
        errorDetails: const [],
        purged: purged,
      );
    }

    test('空扫描：无新文件', () {
      expect(scanResultText(zh, result()), '无新文件');
    });

    test('仅新增', () {
      expect(scanResultText(zh, result(added: 5)), '添加 5 首');
    });

    test('强制刷新：无新增但重解析全部（不误报「添加」）', () {
      expect(scanResultText(zh, result(updated: 120)), '更新 120 首');
    });

    test('新增 + 更新 并存', () {
      expect(
        scanResultText(zh, result(added: 3, updated: 40)),
        '添加 3 首，更新 40 首',
      );
    });

    test('新增 + 移除', () {
      expect(
        scanResultText(zh, result(added: 2, markedMissing: 7)),
        '添加 2 首，7 首已移除',
      );
    });

    test('仅移除（无新增无更新）', () {
      expect(scanResultText(zh, result(markedMissing: 3)), '无新文件，3 首已移除');
    });

    test('仅清理残留', () {
      expect(scanResultText(zh, result(purged: 4)), '无新文件，清理 4 条残留');
    });

    test('移除 + 清理残留并存', () {
      expect(
        scanResultText(zh, result(markedMissing: 2, purged: 3)),
        '无新文件，2 首已移除，清理 3 条残留',
      );
    });

    test('有失败追加失败数', () {
      expect(
        scanResultText(zh, result(updated: 10, errors: 2)),
        '更新 10 首，2 处失败',
      );
    });

    test('全部维度齐全', () {
      expect(
        scanResultText(
          zh,
          result(added: 1, updated: 2, markedMissing: 3, errors: 4),
        ),
        '添加 1 首，更新 2 首，3 首已移除，4 处失败',
      );
    });

    test('英文：复数与逗号分隔', () {
      expect(
        scanResultText(
          en,
          result(added: 1, updated: 2, markedMissing: 3, errors: 4),
        ),
        'Added 1 song, Updated 2 songs, 3 songs removed, 4 failures',
      );
      expect(scanResultText(en, result(added: 2)), 'Added 2 songs');
      expect(scanResultText(en, result()), 'No new files');
    });
  });
}
