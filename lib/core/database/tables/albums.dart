import 'package:drift/drift.dart';

class Albums extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(max: 500)();
  IntColumn get artistId => integer().nullable()();
  TextColumn get albumArtist => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();
  TextColumn get albumArtFilePath => text().nullable()();
  IntColumn get songCount => integer().withDefault(const Constant(0))();
}
