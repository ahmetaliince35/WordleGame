import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('SQLite database can be opened directly via FFI', () async {
    sqfliteFfiInit();
    final dbFactory = databaseFactoryFfi;
    final dbFile = File('data/sozluk.db');
    expect(dbFile.existsSync(), isTrue);

    final db = await dbFactory.openDatabase(dbFile.absolute.path);
    final countRes = await db.rawQuery('SELECT count(*) as total FROM dictionary');
    expect(countRes.first['total'], isNotNull);
    final count = countRes.first['total'] as int;
    expect(count, greaterThan(10000));

    for (final len in [4, 5, 6, 7]) {
      final rows = await db.rawQuery(
        'SELECT word, meaning FROM dictionary WHERE length = ? AND iswithspace = 0 ORDER BY RANDOM() LIMIT 1',
        [len],
      );
      expect(rows, isNotEmpty);
      expect(rows.first['word'], isNotNull);
    }

    await db.close();
  });
}
