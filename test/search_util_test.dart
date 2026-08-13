import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_music/core/utils/search_util.dart';

void main() {
  group('normalizeQuery', () {
    test('去首尾空白并转小写', () {
      expect(normalizeQuery('  Hello World  '), 'hello world');
      expect(normalizeQuery('周杰伦'), '周杰伦');
    });

    test('null 与空串/纯空白返回空串', () {
      expect(normalizeQuery(null), '');
      expect(normalizeQuery(''), '');
      expect(normalizeQuery('   '), '');
    });
  });

  group('containsIgnoreCase', () {
    test('大小写不敏感匹配', () {
      expect(containsIgnoreCase('Jay Chou', normalizeQuery('jay')), isTrue);
      expect(containsIgnoreCase('Jay Chou', normalizeQuery('CHO')), isTrue);
      expect(containsIgnoreCase('周杰伦', normalizeQuery('周杰伦')), isTrue);
    });

    test('子串匹配', () {
      expect(
        containsIgnoreCase('Yellow Submarine', normalizeQuery('sub')),
        isTrue,
      );
    });

    test('查询为空或 source 为 null/空返回 false', () {
      expect(containsIgnoreCase(null, normalizeQuery('x')), isFalse);
      expect(containsIgnoreCase('', normalizeQuery('x')), isFalse);
      expect(containsIgnoreCase('abc', normalizeQuery('')), isFalse);
      expect(containsIgnoreCase('abc', normalizeQuery('   ')), isFalse);
    });

    test('不匹配返回 false', () {
      expect(containsIgnoreCase('abc', normalizeQuery('z')), isFalse);
    });
  });
}
