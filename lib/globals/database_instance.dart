import 'package:jsonld/database/database.dart';

AppDatabase? _db;

AppDatabase get db {
  _db ??= AppDatabase();
  return _db!;
}
