import 'package:drift/drift.dart';

class Artists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  IntColumn get songCount => integer().withDefault(const Constant(0))();
  IntColumn get albumCount => integer().withDefault(const Constant(0))();

  /// 拼音/日文排序键（歌手名）。
  TextColumn get nameSortKey => text().nullable()();
}
