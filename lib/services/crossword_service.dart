import 'dart:math';
import '../models/crossword_model.dart';
import 'database_service.dart';

class _DraftClue {
  final String word;
  final String clue;
  final CrosswordDirection direction;
  final int startRow;
  final int startCol;
  final int length;

  const _DraftClue({
    required this.word,
    required this.clue,
    required this.direction,
    required this.startRow,
    required this.startCol,
    required this.length,
  });
}

class CrosswordService {
  static final CrosswordService _instance = CrosswordService._internal();
  factory CrosswordService() => _instance;
  CrosswordService._internal();

  final Random _random = Random();

  /// Ana erişim noktası: Her el veritabanından TAMAMEN DİNAMİK ve rastgele bulmaca üretir
  Future<CrosswordPuzzle> getRandomPuzzle([String? excludeId]) async {
    try {
      final dynamicPuzzle = await generateDynamicPuzzle();
      return dynamicPuzzle;
    } catch (_) {
      // Beklenmedik bir durumda hazır şablonu zenginleştirerek dön
      return _getRandomFallbackPuzzle(excludeId);
    }
  }

  /// SQLite veritabanındaki 92.000+ kelimeden tamamen rastgele ve dinamik Çengel Bulmaca üretir
  Future<CrosswordPuzzle> generateDynamicPuzzle() async {
    final db = DatabaseService();

    // 5 deneme hakkı vererek kusursuz bir rastgele kesişim kümesi üret
    for (int attempt = 0; attempt < 6; attempt++) {
      try {
        final puzzle = await _tryGenerateDynamicPuzzle(db);
        if (puzzle != null && validatePuzzle(puzzle)) {
          return puzzle;
        }
      } catch (_) {
        // Yeniden dene
      }
    }

    return _getRandomFallbackPuzzle();
  }

  Future<CrosswordPuzzle?> _tryGenerateDynamicPuzzle(DatabaseService db) async {
    const int gridSize = 26;
    final grid = List.generate(gridSize, (_) => List<String?>.filled(gridSize, null));
    final cellDir = List.generate(gridSize, (_) => List<String?>.filled(gridSize, null));

    final placedClues = <_DraftClue>[];
    final usedWords = <String>{};

    // 1. Anchor Word (Merkez kelime)
    final anchor = await db.getRandomWord(5);
    const int startRow = 12;
    const int startCol = 10;
    for (int i = 0; i < anchor.length; i++) {
      grid[startRow][startCol + i] = anchor.word[i];
      cellDir[startRow][startCol + i] = 'A';
    }
    placedClues.add(_DraftClue(
      word: anchor.word,
      clue: anchor.meaning,
      direction: CrosswordDirection.across,
      startRow: startRow,
      startCol: startCol,
      length: anchor.length,
    ));
    usedWords.add(anchor.word);

    // Hedef: 22 - 25 kesişen kelime
    final targetWordCount = 22 + _random.nextInt(4);

    int failStreak = 0;
    while (placedClues.length < targetWordCount && failStreak < 90) {
      final parent = placedClues[_random.nextInt(placedClues.length)];
      final branchDir = parent.direction == CrosswordDirection.across
          ? CrosswordDirection.down
          : CrosswordDirection.across;

      final parentCharIdx = _random.nextInt(parent.length);
      final crossR = parent.direction == CrosswordDirection.across
          ? parent.startRow
          : parent.startRow + parentCharIdx;
      final crossC = parent.direction == CrosswordDirection.across
          ? parent.startCol + parentCharIdx
          : parent.startCol;

      // Zaten her iki yönde kesişmiş bir kavşaksa atla
      if (cellDir[crossR][crossC] == 'B') {
        failStreak++;
        continue;
      }

      final branchLengths = [5, 4, 6]..shuffle(_random);
      bool placedOne = false;

      for (final len in branchLengths) {
        if (placedOne) break;

        final candidateIndices = List.generate(len, (i) => i)..shuffle(_random);
        for (final branchCharIdx in candidateIndices) {
          final newStartR = branchDir == CrosswordDirection.down
              ? crossR - branchCharIdx
              : crossR;
          final newStartC = branchDir == CrosswordDirection.across
              ? crossC - branchCharIdx
              : crossC;

          if (newStartR < 1 || newStartC < 1) continue;
          if (branchDir == CrosswordDirection.down && newStartR + len >= gridSize - 1) continue;
          if (branchDir == CrosswordDirection.across && newStartC + len >= gridSize - 1) continue;

          // Kelime öncesi ve sonrası boşluk olmalı
          final beforeR = branchDir == CrosswordDirection.down ? newStartR - 1 : newStartR;
          final beforeC = branchDir == CrosswordDirection.across ? newStartC - 1 : newStartC;
          if (grid[beforeR][beforeC] != null) continue;

          final afterR = branchDir == CrosswordDirection.down ? newStartR + len : newStartR;
          final afterC = branchDir == CrosswordDirection.across ? newStartC + len : newStartC;
          if (grid[afterR][afterC] != null) continue;

          final constraints = <int, String>{};
          bool isValid = true;

          for (int k = 0; k < len; k++) {
            final r = branchDir == CrosswordDirection.down ? newStartR + k : newStartR;
            final c = branchDir == CrosswordDirection.across ? newStartC + k : newStartC;

            final existingChar = grid[r][c];
            if (existingChar != null) {
              final existingDir = cellDir[r][c];
              final expectedOpposite = branchDir == CrosswordDirection.down ? 'A' : 'D';
              if (existingDir != expectedOpposite) {
                isValid = false;
                break;
              }
              constraints[k] = existingChar;
            } else {
              // Boş hücre: paralel komşuları boş olmalı
              if (branchDir == CrosswordDirection.down) {
                if (grid[r][c - 1] != null || grid[r][c + 1] != null) {
                  isValid = false;
                  break;
                }
              } else {
                if (grid[r - 1][c] != null || grid[r + 1][c] != null) {
                  isValid = false;
                  break;
                }
              }
            }
          }

          if (!isValid || constraints.isEmpty) continue;

          final candidates = await db.findWordsMatching(
            length: len,
            letterAtIndices: constraints,
            excludeWords: usedWords,
            limit: 12,
          );

          if (candidates.isNotEmpty) {
            final chosen = candidates[_random.nextInt(candidates.length)];
            usedWords.add(chosen.word);

            for (int k = 0; k < len; k++) {
              final r = branchDir == CrosswordDirection.down ? newStartR + k : newStartR;
              final c = branchDir == CrosswordDirection.across ? newStartC + k : newStartC;
              grid[r][c] = chosen.word[k];
              cellDir[r][c] = (cellDir[r][c] == null)
                  ? (branchDir == CrosswordDirection.down ? 'D' : 'A')
                  : 'B';
            }

            placedClues.add(_DraftClue(
              word: chosen.word,
              clue: chosen.meaning,
              direction: branchDir,
              startRow: newStartR,
              startCol: newStartC,
              length: len,
            ));

            placedOne = true;
            failStreak = 0;
            break;
          }
        }
      }

      if (!placedOne) {
        failStreak++;
      }
    }

    if (placedClues.length < 18) {
      return null;
    }

    // Koordinatları 0-tabanlı normalize et
    int minRow = placedClues.map((c) => c.startRow).reduce(min);
    int minCol = placedClues.map((c) => c.startCol).reduce(min);

    int maxRow = 0;
    int maxCol = 0;

    final normalizedDrafts = <_DraftClue>[];
    for (final c in placedClues) {
      final nr = c.startRow - minRow;
      final nc = c.startCol - minCol;
      normalizedDrafts.add(_DraftClue(
        word: c.word,
        clue: c.clue,
        direction: c.direction,
        startRow: nr,
        startCol: nc,
        length: c.length,
      ));

      final endR = c.direction == CrosswordDirection.across ? nr : nr + c.length - 1;
      final endC = c.direction == CrosswordDirection.across ? nc + c.length - 1 : nc;
      if (endR > maxRow) maxRow = endR;
      if (endC > maxCol) maxCol = endC;
    }

    // Okuma sırasına göre sırala ve numaralandır
    normalizedDrafts.sort((a, b) {
      if (a.startRow != b.startRow) return a.startRow.compareTo(b.startRow);
      return a.startCol.compareTo(b.startCol);
    });

    final finalClues = <CrosswordClue>[];
    for (int i = 0; i < normalizedDrafts.length; i++) {
      final d = normalizedDrafts[i];
      finalClues.add(CrosswordClue(
        id: i + 1,
        word: d.word,
        clue: d.clue,
        direction: d.direction,
        startRow: d.startRow,
        startCol: d.startCol,
        length: d.length,
      ));
    }

    return CrosswordPuzzle(
      id: 'dyn_${DateTime.now().microsecondsSinceEpoch}',
      title: 'Büyük Çengel (${finalClues.length} Kelime)',
      rows: maxRow + 1,
      cols: maxCol + 1,
      clues: finalClues,
    );
  }

  /// Bulmaca doğruluğunu denetler (Kesişim çelişkisi kontrolü)
  bool validatePuzzle(CrosswordPuzzle puzzle) {
    final cellMap = <String, String>{};
    for (final clue in puzzle.clues) {
      for (int i = 0; i < clue.length; i++) {
        final r = clue.getRowForIndex(i);
        final c = clue.getColForIndex(i);
        final char = clue.word[i];
        final key = '$r,$c';
        if (cellMap.containsKey(key)) {
          if (cellMap[key] != char) {
            return false;
          }
        } else {
          cellMap[key] = char;
        }
      }
    }
    return true;
  }

  /// Acil durum veya veritabanı gecikmesi durumunda zenginleştirilmiş yedek bulmaca
  Future<CrosswordPuzzle> _getRandomFallbackPuzzle([String? excludeId]) async {
    final available = _fallbackPuzzles.where((p) => p.id != excludeId).toList();
    final chosen = available.isNotEmpty
        ? available[_random.nextInt(available.length)]
        : _fallbackPuzzles[_random.nextInt(_fallbackPuzzles.length)];

    final enrichedClues = <CrosswordClue>[];
    final db = DatabaseService();

    for (final clue in chosen.clues) {
      String meaning = clue.clue;
      try {
        final dbMeaning = await db.getMeaning(clue.word);
        if (dbMeaning != null && dbMeaning.trim().isNotEmpty) {
          meaning = dbMeaning.trim();
        }
      } catch (_) {}

      enrichedClues.add(CrosswordClue(
        id: clue.id,
        word: clue.word,
        clue: meaning,
        direction: clue.direction,
        startRow: clue.startRow,
        startCol: clue.startCol,
        length: clue.length,
      ));
    }

    return CrosswordPuzzle(
      id: '${chosen.id}_${DateTime.now().millisecondsSinceEpoch}',
      title: chosen.title,
      rows: chosen.rows,
      cols: chosen.cols,
      clues: enrichedClues,
    );
  }

  final List<CrosswordPuzzle> _fallbackPuzzles = [
    CrosswordPuzzle(
      id: 'fb_buyuk_1',
      title: 'Büyük Çengel (25 Kelime)',
      rows: 13,
      cols: 13,
      clues: [
        // Yatay Kelimeler
        CrosswordClue(
          id: 1,
          word: 'KİTAP',
          clue: 'Basılı veya yazılı kâğıt yaprakların bir araya getirilmiş bütünü.',
          direction: CrosswordDirection.across,
          startRow: 1,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 2,
          word: 'SANAT',
          clue: 'Duygu ve düşüncelerin yaratıcı biçimde ifadesi.',
          direction: CrosswordDirection.across,
          startRow: 1,
          startCol: 7,
          length: 5,
        ),
        CrosswordClue(
          id: 3,
          word: 'LİRİK',
          clue: 'Çok duygusal, coşkun, ilham dolu edebiyat veya şiir türü.',
          direction: CrosswordDirection.across,
          startRow: 3,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 4,
          word: 'BAHAR',
          clue: 'Kış ile yaz arasındaki ılık ve canlandırıcı mevsim.',
          direction: CrosswordDirection.across,
          startRow: 3,
          startCol: 7,
          length: 5,
        ),
        CrosswordClue(
          id: 5,
          word: 'MÜHÜR',
          clue: 'Bir kimsenin veya kurumun adını taşıyan resmi damga.',
          direction: CrosswordDirection.across,
          startRow: 5,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 6,
          word: 'RESİM',
          clue: 'Varlıkların çizgi ve renklerle yüzey üzerine yansıtılması sanatı.',
          direction: CrosswordDirection.across,
          startRow: 5,
          startCol: 7,
          length: 5,
        ),
        CrosswordClue(
          id: 7,
          word: 'DEMİR',
          clue: 'Sanayide ve yapılarda çok kullanılan dayanıklı metal elementi.',
          direction: CrosswordDirection.across,
          startRow: 7,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 8,
          word: 'BULUT',
          clue: 'Gökyüzünde su damlacıklarından oluşan beyaz veya gri küme.',
          direction: CrosswordDirection.across,
          startRow: 7,
          startCol: 7,
          length: 5,
        ),
        CrosswordClue(
          id: 9,
          word: 'LİMON',
          clue: 'Ekşi tadı ve sarı kabuğu olan C vitamini zengini narenciye.',
          direction: CrosswordDirection.across,
          startRow: 9,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 10,
          word: 'DENİZ',
          clue: 'Karaları çevreleyen geniş, tuzlu su kütlesi.',
          direction: CrosswordDirection.across,
          startRow: 9,
          startCol: 7,
          length: 5,
        ),
        CrosswordClue(
          id: 11,
          word: 'AHMET',
          clue: 'Övgüye değer, methedilmiş anlamında yaygın Türkçe erkek ismi.',
          direction: CrosswordDirection.across,
          startRow: 11,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 12,
          word: 'MÜZİK',
          clue: 'Sesleri melodi, ritim ve armoniyle estetik bir biçimde düzenleme sanatı.',
          direction: CrosswordDirection.across,
          startRow: 11,
          startCol: 7,
          length: 5,
        ),

        // Dikey Kelimeler
        CrosswordClue(
          id: 13,
          word: 'KALEM',
          clue: 'Yazma ve çizme işlerinde kullanılan uçlu araç.',
          direction: CrosswordDirection.down,
          startRow: 1,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 14,
          word: 'TARİH',
          clue: 'Geçmişteki olayları zaman ve yer göstererek inceleyen bilim.',
          direction: CrosswordDirection.down,
          startRow: 1,
          startCol: 3,
          length: 5,
        ),
        CrosswordClue(
          id: 15,
          word: 'ARİF',
          clue: 'Çok anlayışlı, sezgili, olayların iç yüzünü kavrayan bilge kimse.',
          direction: CrosswordDirection.down,
          startRow: 1,
          startCol: 4,
          length: 4,
        ),
        CrosswordClue(
          id: 16,
          word: 'POKER',
          clue: 'Özel kart destesiyle oynanan strateji ve şans oyunu.',
          direction: CrosswordDirection.down,
          startRow: 1,
          startCol: 5,
          length: 5,
        ),
        CrosswordClue(
          id: 17,
          word: 'SABIR',
          clue: 'Zorluklar karşısında metanet gösterme, dayanma gücü.',
          direction: CrosswordDirection.down,
          startRow: 1,
          startCol: 7,
          length: 5,
        ),
        CrosswordClue(
          id: 18,
          word: 'ADAM',
          clue: 'İnsan, yetişkin erkek veya güvenilir kişilik sahibi kimse.',
          direction: CrosswordDirection.down,
          startRow: 1,
          startCol: 10,
          length: 4,
        ),
        CrosswordClue(
          id: 19,
          word: 'TARIM',
          clue: 'Toprağı işleyerek bitkisel ve hayvansal ürünler elde etme faaliyeti.',
          direction: CrosswordDirection.down,
          startRow: 1,
          startCol: 11,
          length: 5,
        ),
        CrosswordClue(
          id: 20,
          word: 'DALGA',
          clue: 'Deniz yüzeyinde rüzgâr ve akıntılarla oluşan kıvrımlı hareket.',
          direction: CrosswordDirection.down,
          startRow: 7,
          startCol: 1,
          length: 5,
        ),
        CrosswordClue(
          id: 21,
          word: 'MİMAR',
          clue: 'Binaların plan ve tasarımlarını yapan yapı uzmanı.',
          direction: CrosswordDirection.down,
          startRow: 7,
          startCol: 3,
          length: 5,
        ),
        CrosswordClue(
          id: 22,
          word: 'RENK',
          clue: 'Işığın cisimlere çarparak gözde uyandırdığı görsel duyum.',
          direction: CrosswordDirection.down,
          startRow: 7,
          startCol: 5,
          length: 4,
        ),
        CrosswordClue(
          id: 23,
          word: 'BADEM',
          clue: 'Sert kabuklu, besleyici ve lezzetli bir kuru yemiş ağacı türü.',
          direction: CrosswordDirection.down,
          startRow: 7,
          startCol: 7,
          length: 5,
        ),
        CrosswordClue(
          id: 24,
          word: 'LİNK',
          clue: 'İnternet sayfaları veya belgeler arasındaki tıklanabilir bağlantı.',
          direction: CrosswordDirection.down,
          startRow: 7,
          startCol: 9,
          length: 4,
        ),
        CrosswordClue(
          id: 25,
          word: 'ZEKA',
          clue: 'İnsanın düşünme, akıl yürütme ve problem çözme yeteneği.',
          direction: CrosswordDirection.down,
          startRow: 9,
          startCol: 11,
          length: 4,
        ),
      ],
    ),
  ];
}
