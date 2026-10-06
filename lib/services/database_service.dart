import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/letter_state.dart';
import '../utils/turkish_helper.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  sqflite.Database? _database;
  bool _isInitialized = false;

  final Map<int, Set<String>> _validWordsCache = {};
  final Random _random = Random();

  Future<void> initialize() async {
    if (_isInitialized && _database != null) return;

    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      sqflite.databaseFactory = databaseFactoryFfi;
    }

    String dbPath = '';

    final localDevFile = File('data/sozluk.db');
    if (localDevFile.existsSync()) {
      dbPath = localDevFile.absolute.path;
    } else {
      final appDocDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(appDocDir.path, 'sozluk.db');
      final targetFile = File(dbPath);

      // Hedef klasörün var olduğundan emin ol
      await targetFile.parent.create(recursive: true);

      // Sadece dosya yoksa veya bozuksa kopyala
      if (!targetFile.existsSync() || (await targetFile.length()) < 1024) {
        final data = await rootBundle.load('data/sozluk.db');
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await targetFile.writeAsBytes(bytes, flush: true);
      }
    }

    _database = await sqflite.openDatabase(
      dbPath,
      readOnly: false,
    );
    _isInitialized = true;
  }

  sqflite.Database get _db {
    if (_database == null) {
      throw StateError('Database not initialized. Call initialize() first.');
    }
    return _database!;
  }

  Future<Set<String>> getValidWordsForLength(int length) async {
    if (_validWordsCache.containsKey(length)) {
      return _validWordsCache[length]!;
    }

    final rows = await _db.rawQuery(
      'SELECT word FROM dictionary WHERE length = ? AND iswithspace = 0',
      [length],
    );

    final set = <String>{};
    for (final row in rows) {
      final rawWord = row['word'] as String?;
      if (rawWord == null) continue;

      final normalized = TurkishHelper.toTurkishUpper(rawWord);
      if (TurkishHelper.isValidTurkishWord(normalized, length)) {
        set.add(normalized);
      }
    }

    _validWordsCache[length] = set;
    return set;
  }

  Future<bool> isValidWord(String word, int length) async {
    final normalized = TurkishHelper.toTurkishUpper(word);
    if (!TurkishHelper.isValidTurkishWord(normalized, length)) return false;

    if (_validWordsCache.containsKey(length) && _validWordsCache[length]!.contains(normalized)) {
      return true;
    }

    final lower = TurkishHelper.toTurkishLower(word);
    final rows = await _db.rawQuery(
      'SELECT 1 FROM dictionary WHERE (word = ? OR word = ?) AND length = ? AND iswithspace = 0 LIMIT 1',
      [lower, normalized, length],
    );

    if (rows.isNotEmpty) {
      _validWordsCache.putIfAbsent(length, () => <String>{}).add(normalized);
      return true;
    }
    return false;
  }

  /// ORDER BY RANDOM() yerine OFFSET kullanarak 0 milisaniyede kelime seçer
  Future<WordData> getRandomWord(int length) async {
    // 1. Önce o harf uzunluğundaki toplam kayıt sayısını al (indeksli, anında döner)
    final countResult = await _db.rawQuery(
      'SELECT COUNT(*) as total FROM dictionary WHERE length = ? AND iswithspace = 0',
      [length],
    );

    final total = sqflite.Sqflite.firstIntValue(countResult) ?? 0;
    if (total == 0) {
      throw Exception('$length harfli uygun kelime bulunamadı.');
    }

    // 2. Rastgele bir satır numarası seç (Rastgele LIMIT 1 OFFSET X ile anında çeker)
    for (int attempt = 0; attempt < 5; attempt++) {
      final randomOffset = _random.nextInt(total);
      final rows = await _db.rawQuery(
        'SELECT word, meaning FROM dictionary WHERE length = ? AND iswithspace = 0 LIMIT 1 OFFSET ?',
        [length, randomOffset],
      );

      if (rows.isNotEmpty) {
        final rawWord = (rows.first['word'] as String?)?.trim();
        final meaning = (rows.first['meaning'] as String?)?.trim() ?? 'Anlam bulunamadı.';

        if (rawWord != null) {
          final normalized = TurkishHelper.toTurkishUpper(rawWord);
          if (TurkishHelper.isValidTurkishWord(normalized, length)) {
            return WordData(
              word: normalized,
              meaning: meaning.isEmpty ? 'TDK sözlüğünde kayıtlı kelime.' : meaning,
              length: length,
            );
          }
        }
      }
    }

    throw Exception('$length harfli uygun kelime bulunamadı.');
  }

  /// Adam Asmaca için her türden (harf sınırı olmaksızın tek kelime veya boşluklu tamlama) rastgele sözcük/ifade seçer
  Future<WordData> getRandomHangmanWord({int minLength = 4, int maxLength = 18}) async {
    final countResult = await _db.rawQuery(
      'SELECT COUNT(*) as total FROM dictionary WHERE length >= ? AND length <= ?',
      [minLength, maxLength],
    );

    final total = sqflite.Sqflite.firstIntValue(countResult) ?? 0;
    if (total == 0) {
      return getRandomWord(6);
    }

    for (int attempt = 0; attempt < 10; attempt++) {
      final randomOffset = _random.nextInt(total);
      final rows = await _db.rawQuery(
        'SELECT word, meaning, length FROM dictionary WHERE length >= ? AND length <= ? LIMIT 1 OFFSET ?',
        [minLength, maxLength, randomOffset],
      );

      if (rows.isNotEmpty) {
        final rawWord = (rows.first['word'] as String?)?.trim();
        final meaning = (rows.first['meaning'] as String?)?.trim() ?? 'TDK sözlüğünde kayıtlı kelime.';
        final len = (rows.first['length'] as int?) ?? rawWord?.length ?? 0;

        if (rawWord != null && rawWord.length >= minLength) {
          final normalized = TurkishHelper.toTurkishUpper(rawWord);
          // Yalnızca Türkçe harfler ve boşluk içeren ifadeleri kabul et
          final isValid = RegExp(r'^[A-ZÇĞİÖŞÜ\s]+$').hasMatch(normalized);
          if (isValid) {
            return WordData(
              word: normalized,
              meaning: (meaning.isEmpty || meaning == 'null')
                  ? 'TDK sözlüğünde kayıtlı kelime.'
                  : meaning,
              length: len,
            );
          }
        }
      }
    }

    return getRandomWord(6);
  }

  Future<String?> getMeaning(String word) async {
    final lower = TurkishHelper.toTurkishLower(word);
    final rows = await _db.rawQuery(
      'SELECT meaning FROM dictionary WHERE LOWER(word) = ? OR word = ? LIMIT 1',
      [lower, lower],
    );

    if (rows.isNotEmpty) {
      return rows.first['meaning'] as String?;
    }
    return null;
  }

  /// Çengel bulmaca kesişimleri için belirli harf konumlarına uyan kelimeleri SQLite'tan çeker
  Future<List<WordData>> findWordsMatching({
    required int length,
    required Map<int, String> letterAtIndices,
    Set<String>? excludeWords,
    int limit = 40,
  }) async {
    final whereClauses = <String>['length = ?', 'iswithspace = 0'];
    final whereArgs = <dynamic>[length];

    for (final entry in letterAtIndices.entries) {
      final pos = entry.key + 1;
      final upperChar = TurkishHelper.toTurkishUpper(entry.value);
      final lowerChar = TurkishHelper.toTurkishLower(entry.value);
      whereClauses.add('(substr(word, $pos, 1) = ? OR substr(word, $pos, 1) = ?)');
      whereArgs.add(lowerChar);
      whereArgs.add(upperChar);
    }

    final sql = '''
      SELECT word, meaning FROM dictionary 
      WHERE ${whereClauses.join(' AND ')}
      LIMIT ?
    ''';
    whereArgs.add(limit * 2);

    final rows = await _db.rawQuery(sql, whereArgs);
    final results = <WordData>[];
    for (final row in rows) {
      final rawWord = (row['word'] as String?)?.trim();
      final meaning = (row['meaning'] as String?)?.trim() ?? '';
      if (rawWord != null) {
        final normalized = TurkishHelper.toTurkishUpper(rawWord);
        if (excludeWords != null && excludeWords.contains(normalized)) {
          continue;
        }
        if (TurkishHelper.isValidTurkishWord(normalized, length)) {
          results.add(WordData(
            word: normalized,
            meaning: (meaning.isEmpty || meaning == 'null')
                ? 'TDK sözlüğünde kayıtlı kelime.'
                : meaning,
            length: length,
          ));
          if (results.length >= limit) break;
        }
      }
    }
    return results;
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _isInitialized = false;
  }
}