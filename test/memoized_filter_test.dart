import 'package:flutter_test/flutter_test.dart';

import 'package:txvziwm/core/utils/memoized_filter.dart';

void main() {
  List<String> filterBy(String q, List<String> source) =>
      source.where((e) => e.toLowerCase().contains(q)).toList();

  test('query 与源列表均未变 → 命中缓存（filter 只调一次、结果同实例）', () {
    final cache = QueryFilterCache<String>();
    var calls = 0;
    final source = ['Apple', 'Banana', 'Apricot'];

    final r1 = cache.get('ap', source, (q, s) {
      calls++;
      return filterBy(q, s);
    });
    final r2 = cache.get('ap', source, (q, s) {
      calls++;
      return filterBy(q, s);
    });

    expect(r1, ['Apple', 'Apricot']);
    expect(r2, same(r1));
    expect(calls, 1);
  });

  test('query 变化 → 重算', () {
    final cache = QueryFilterCache<String>();
    var calls = 0;
    final source = ['Apple', 'Banana', 'Apricot'];

    cache.get('ap', source, (q, s) {
      calls++;
      return filterBy(q, s);
    });
    final r = cache.get('ba', source, (q, s) {
      calls++;
      return filterBy(q, s);
    });

    expect(r, ['Banana']);
    expect(calls, 2);
  });

  test('源列表引用变化（ViewModel load 替换）→ 重算', () {
    final cache = QueryFilterCache<String>();
    var calls = 0;
    final srcA = ['Apple'];
    final srcB = ['Apple', 'Banana'];

    cache.get('a', srcA, (q, s) {
      calls++;
      return filterBy(q, s);
    });
    final r = cache.get('a', srcB, (q, s) {
      calls++;
      return filterBy(q, s);
    });

    expect(r, ['Apple', 'Banana']);
    expect(calls, 2);
  });

  test('空 query → 直接返回源列表本身、不调用 filter', () {
    final cache = QueryFilterCache<String>();
    var calls = 0;
    final source = ['Apple'];

    final r = cache.get('', source, (q, s) {
      calls++;
      return s;
    });

    expect(r, same(source));
    expect(calls, 0);
  });
}
