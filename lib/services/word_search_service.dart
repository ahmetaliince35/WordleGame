import 'dart:math';
import '../services/database_service.dart';
import '../utils/turkish_helper.dart';

class GridPoint {
  final int row;
  final int col;

  const GridPoint(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GridPoint && runtimeType == other.runtimeType && row == other.row && col == other.col;

  @override
  int get hashCode => row.hashCode ^ col.hashCode;
}

class WordSearchItem {
  final String word;
  final String meaning;
  final List<GridPoint> path;
  bool isFound;
  final int colorIndex;

  WordSearchItem({
    required this.word,
    required this.meaning,
    required this.path,
    this.isFound = false,
    required this.colorIndex,
  });
}

class WordSearchPuzzle {
  final List<List<String>> grid;
  final List<WordSearchItem> words;

  const WordSearchPuzzle({
    required this.grid,
    required this.words,
  });
}

class WordSearchService {
  static final WordSearchService _instance = WordSearchService._internal();
  factory WordSearchService() => _instance;
  WordSearchService._internal();

  final Random _random = Random();
  static const int gridSize = 12;

  // 8 Yön vektörleri: Yatay, Dikey ve Çapraz
  static const List<List<int>> _directions = [
    [0, 1],   // Sağa
    [0, -1],  // Sola
    [1, 0],   // Aşağı
    [-1, 0],  // Yukarı
    [1, 1],   // Sağ Aşağı (Çapraz)
    [1, -1],  // Sol Aşağı (Çapraz)
    [-1, 1],  // Sağ Yukarı (Çapraz)
    [-1, -1], // Sol Yukarı (Çapraz)
  ];

  // Türkçe harf frekans havuzu (boş kalan kutuları doldurmak için)
  static const String _turkishLetters =
      'AAAAABBBBCCCÇÇDDDDEEEEEFFFGGĞĞHHHIIIİİİİJKKKLLLMMMNNNNOOOÖPPRRRSSŞŞTTTTUUÜÜVVYYZZ';

  // Güvenli yedek kelime ve anlam havuzu
  static const List<Map<String, String>> _fallbackWords = [
    {'word': 'GÖKYÜZÜ', 'meaning': 'Havanın açık olduğu zamanlarda mavi renkli görünen gök kubbe.'},
    {'word': 'PIRLANTA', 'meaning': 'Elmasın özel olarak yontulmuş ve parlatılmış hali.'},
    {'word': 'FIRTINA', 'meaning': 'Rüzgârın şiddetli esmesiyle oluşan hava olayı.'},
    {'word': 'GÖKKUŞAĞI', 'meaning': 'Yağmur damlalarından geçen güneş ışıklarının oluşturduğu renkli yay.'},
    {'word': 'PUSULA', 'meaning': 'Yön gösteren ibreli mıknatıslı araç.'},
    {'word': 'DENİZALTı', 'meaning': 'Denizin altından gidebilen savaş veya keşif gemisi.'},
    {'word': 'KASIRGA', 'meaning': 'Hızı saatte yüz kilometreyi aşan çok şiddetli döner fırtına.'},
    {'word': 'ŞELALE', 'meaning': 'Yüksek bir yerden dik olarak dökülen akarsu, çavlan.'},
    {'word': 'YANARDAĞ', 'meaning': 'Magmanın yeryüzüne lav ve gaz püskürttüğü dağ, volkan.'},
    {'word': 'KÜTÜPHANE', 'meaning': 'Kitapların toplandığı ve okunduğu yer.'},
    {'word': 'MENEKŞE', 'meaning': 'Hoş kokulu, koyu mor renkli çiçekler açan bitki.'},
    {'word': 'KARDELEN', 'meaning': 'Karlar arasından açan beyaz soğanlı kış çiçeği.'},
    {'word': 'YAKAMOZ', 'meaning': 'Denizdeki mikroskobik canlıların ışıldamasıyla suda oluşan parıltı.'},
    {'word': 'GÜVERCİN', 'meaning': 'Barışın simgesi sayılan evcil veya yaban kuşu.'},
    {'word': 'ÇINAR', 'meaning': 'Uzun ömürlü, gövdesi çok kalın ulu ağaç.'},
    {'word': 'GÜNEŞLİK', 'meaning': 'Güneş ışığını kesmek için kullanılan tente veya perde.'},
  ];

  /// 12x12 matris ve yerleştirilmiş kelimeleri üretir
  Future<WordSearchPuzzle> generatePuzzle() async {
    final db = DatabaseService();

    // 1. Veritabanından veya yedekten 10-14 kelime topla
    final candidates = <Map<String, String>>[];

    try {
      await db.initialize();
      final lengths = [4, 5, 6, 7, 8]..shuffle(_random);
      for (final len in lengths) {
        for (int i = 0; i < 3; i++) {
          final wordData = await db.getRandomWord(len);
          final upper = TurkishHelper.toTurkishUpper(wordData.word);
          if (upper.length >= 4 && upper.length <= 8 && !candidates.any((c) => c['word'] == upper)) {
            candidates.add({'word': upper, 'meaning': wordData.meaning});
          }
        }
      }
    } catch (_) {
      // Veritabanı meşgulse yedekten al
    }

    if (candidates.length < 8) {
      for (final fb in _fallbackWords) {
        if (!candidates.any((c) => c['word'] == fb['word'])) {
          candidates.add(fb);
        }
      }
    }

    candidates.shuffle(_random);

    // 2. 12x12 boş ızgara oluştur
    final grid = List.generate(gridSize, (_) => List.filled(gridSize, ''));
    final placedWords = <WordSearchItem>[];

    // 3. Kelimeleri ızgaraya yerleştirmeyi dene (Hedef: 8 - 10 kelime)
    int colorCounter = 0;

    for (final candidate in candidates) {
      if (placedWords.length >= 9) break;

      final word = candidate['word']!;
      final meaning = candidate['meaning']!;
      final len = word.length;
      if (len > gridSize) continue;

      bool isPlaced = false;

      // Bu kelime için 120 rastgele konum ve yön dene
      for (int attempt = 0; attempt < 120; attempt++) {
        final dir = _directions[_random.nextInt(_directions.length)];
        final dRow = dir[0];
        final dCol = dir[1];

        // Başlangıç sınırlarını hesapla
        final minRow = (dRow < 0) ? len - 1 : 0;
        final maxRow = (dRow > 0) ? gridSize - len : gridSize - 1;
        final minCol = (dCol < 0) ? len - 1 : 0;
        final maxCol = (dCol > 0) ? gridSize - len : gridSize - 1;

        if (minRow > maxRow || minCol > maxCol) continue;

        final startRow = minRow + _random.nextInt(maxRow - minRow + 1);
        final startCol = minCol + _random.nextInt(maxCol - minCol + 1);

        // Çakışma kontrolü
        bool canFit = true;
        final path = <GridPoint>[];

        for (int i = 0; i < len; i++) {
          final r = startRow + (i * dRow);
          final c = startCol + (i * dCol);
          final cell = grid[r][c];

          if (cell != '' && cell != word[i]) {
            canFit = false;
            break;
          }
          path.add(GridPoint(r, c));
        }

        if (canFit) {
          // Izgaraya yerleştir
          for (int i = 0; i < len; i++) {
            final pt = path[i];
            grid[pt.row][pt.col] = word[i];
          }

          placedWords.add(WordSearchItem(
            word: word,
            meaning: meaning,
            path: path,
            colorIndex: colorCounter % 8,
          ));
          colorCounter++;
          isPlaced = true;
          break;
        }
      }

      if (isPlaced && placedWords.length >= 9) {
        break;
      }
    }

    // 4. Kalan boş hücreleri rastgele Türkçe harflerle doldur
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (grid[r][c] == '') {
          grid[r][c] = _turkishLetters[_random.nextInt(_turkishLetters.length)];
        }
      }
    }

    return WordSearchPuzzle(
      grid: grid,
      words: placedWords,
    );
  }
}
