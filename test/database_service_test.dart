import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_dunyasi/services/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('DatabaseService initializes, fetches random words and validates words', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbService = DatabaseService();
    await dbService.initialize();

    for (final len in [4, 5, 6, 7]) {
      final wordData = await dbService.getRandomWord(len);
      expect(wordData.word.length, equals(len));
      expect(wordData.meaning.isNotEmpty, isTrue);

      final isValid = await dbService.isValidWord(wordData.word, len);
      expect(isValid, isTrue);
    }

    final isNotValid = await dbService.isValidWord('ZZZZZ', 5);
    expect(isNotValid, isFalse);

    await dbService.close();
  });
}
