import 'package:flutter_test/flutter_test.dart';
import 'package:txvziwm/core/utils/index_letters.dart';
import 'package:txvziwm/core/utils/sort_key.dart';

void main() {
  group('indexLetterFor', () {
    test('英文小写排序键 → 大写字母', () {
      expect(indexLetterFor('hello', ''), 'H');
      expect(indexLetterFor('zebra', ''), 'Z');
    });

    test('英文大写原文兜底 → 原字母', () {
      expect(indexLetterFor(null, 'Hello'), 'H');
      expect(indexLetterFor(null, 'Abc'), 'A');
    });

    test('中文拼音排序键 → 拼音首字母', () {
      expect(indexLetterFor('zhongwen', '中文'), 'Z');
      expect(indexLetterFor('hua', '花'), 'H');
    });

    test('与 buildSortKey 集成', () {
      expect(indexLetterFor(buildSortKey('中文'), '中文'), 'Z');
      expect(indexLetterFor(buildSortKey('Abc'), 'Abc'), 'A');
      expect(indexLetterFor(buildSortKey('花'), '花'), 'H');
    });

    test('平假名 → 五十音行', () {
      expect(indexLetterFor('あおい', ''), 'あ');
      expect(indexLetterFor('かん', ''), 'か');
      expect(indexLetterFor('さくら', ''), 'さ');
      expect(indexLetterFor('たけ', ''), 'た');
      expect(indexLetterFor('なみ', ''), 'な');
      expect(indexLetterFor('はる', ''), 'は');
      expect(indexLetterFor('まつ', ''), 'ま');
      expect(indexLetterFor('やま', ''), 'や');
      expect(indexLetterFor('らく', ''), 'ら');
      expect(indexLetterFor('わた', ''), 'わ');
    });

    test('片假名 → 五十音行', () {
      expect(indexLetterFor('カン', ''), 'か');
      expect(indexLetterFor('サクラ', ''), 'さ');
      expect(indexLetterFor('ハル', ''), 'は');
      expect(indexLetterFor('ン', ''), 'わ');
    });

    test('浊音/半浊音 → 归对应清音行', () {
      expect(indexLetterFor('がく', ''), 'か');
      expect(indexLetterFor('ざ', ''), 'さ');
      expect(indexLetterFor('だ', ''), 'た');
      expect(indexLetterFor('ば', ''), 'は');
      expect(indexLetterFor('ぱ', ''), 'は');
    });

    test('拗音/促音小写假名 → 按首假名归行', () {
      expect(indexLetterFor('きゃ', ''), 'か');
      expect(indexLetterFor('しゃ', ''), 'さ');
      expect(indexLetterFor('っ', ''), 'た');
    });

    test('数字/符号/无法归类 → #', () {
      expect(indexLetterFor('123', ''), '#');
      expect(indexLetterFor(null, '★'), '#');
      expect(indexLetterFor(null, '12'), '#');
      expect(indexLetterFor(null, '中'), '#');
    });

    test('空/null 兜底', () {
      expect(indexLetterFor(null, ''), '#');
      expect(indexLetterFor('', ''), '#');
      expect(indexLetterFor(null, 'Hello'), 'H');
    });
  });
}
