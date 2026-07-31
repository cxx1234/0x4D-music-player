import 'package:drift/drift.dart';

/// 用户创建的手动播放列表。
class Playlists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 200)();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}
