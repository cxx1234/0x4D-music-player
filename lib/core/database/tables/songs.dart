import 'package:drift/drift.dart';

class Songs extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(max: 500)();
  TextColumn get artist => text().withLength(max: 500).nullable()();
  TextColumn get album => text().withLength(max: 500).nullable()();
  IntColumn get artistId => integer().nullable()();
  IntColumn get albumId => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  IntColumn get discNumber => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get filePath => text().unique()();
  TextColumn get fileName => text().withLength(max: 500)();
  IntColumn get fileSize => integer().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get year => integer().nullable()();
  TextColumn get genre => text().nullable()();
  IntColumn get bitrate => integer().nullable()();
  IntColumn get sampleRate => integer().nullable()();
  TextColumn get albumArtFilePath => text().nullable()();
  TextColumn get lyricsFilePath => text().nullable()();
  IntColumn get hasEmbeddedArt => integer().withDefault(const Constant(0))();
  IntColumn get hasEmbeddedLyrics => integer().withDefault(const Constant(0))();
  DateTimeColumn get dateAdded => dateTime()();
  IntColumn get playCount => integer().withDefault(const Constant(0))();
  IntColumn get isFavorite => integer().withDefault(const Constant(0))();
  IntColumn get isAvailable => integer().withDefault(const Constant(1))();

  /// 拼音/日文排序键（含日文假名时按原文，否则按拼音小写全拼）。
  TextColumn get titleSortKey => text().nullable()();
}
