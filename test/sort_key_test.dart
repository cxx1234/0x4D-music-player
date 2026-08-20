import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/utils/sort_key.dart';

void main() {
  test('空/空白返回空串', () {
    expect(buildSortKey(''), '');
    expect(buildSortKey('   '), '');
  });

  test('拉丁字符原样保留并小写', () {
    expect(buildSortKey('Lemon'), 'lemon');
    expect(buildSortKey('Hello World'), 'hello world');
  });

  test('中文转小写全拼，保留非中文字符', () {
    expect(buildSortKey('世界'), 'shijie');
    expect(buildSortKey('海阔天空'), 'haikuotiankong');
    expect(buildSortKey('Taylor 世界'), 'taylor shijie');
  });

  test('日文假名不做拼音转换（保留原文）', () {
    // 平假名
    expect(buildSortKey('桜色舞うころ'), '桜色舞うころ');
    // 片假名
    expect(buildSortKey('サザンカ'), 'サザンカ');
    // 汉字 + 假名混合
    expect(buildSortKey('夜に駆ける'), '夜に駆ける');
  });
}
