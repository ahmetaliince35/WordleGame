import 'dart:math';

class SudokuPuzzle {
  final List<List<int>> solution;
  final List<List<int>> initial;
  final String difficulty;

  const SudokuPuzzle({
    required this.solution,
    required this.initial,
    required this.difficulty,
  });
}

class SudokuService {
  static final SudokuService _instance = SudokuService._internal();
  factory SudokuService() => _instance;
  SudokuService._internal();

  final Random _random = Random();

  SudokuPuzzle generatePuzzle(String difficulty) {
    // 1. Tam ve geçerli bir 9x9 çözüm matrisi oluştur
    final solution = List.generate(9, (_) => List.filled(9, 0));
    _fillDiagonalBoxes(solution);
    _solveGrid(solution);

    // 2. Zorluğa göre açık kalacak ipucu sayısını belirle
    int cluesCount;
    switch (difficulty) {
      case 'Kolay':
        cluesCount = 42;
        break;
      case 'Orta':
        cluesCount = 33;
        break;
      case 'Zor':
        cluesCount = 27;
        break;
      case 'Çok Zor':
        cluesCount = 23;
        break;
      default:
        cluesCount = 33;
        break;
    }

    // 3. Çözümden kopya oluştur ve belirlenen sayıda hücreyi boşalt (0 yap)
    final initial = List.generate(9, (r) => List<int>.from(solution[r]));
    final cellsToRemove = 81 - cluesCount;

    final cellIndices = List.generate(81, (index) => index)..shuffle(_random);

    for (int i = 0; i < cellsToRemove; i++) {
      final index = cellIndices[i];
      final row = index ~/ 9;
      final col = index % 9;
      initial[row][col] = 0;
    }

    return SudokuPuzzle(
      solution: solution,
      initial: initial,
      difficulty: difficulty,
    );
  }

  /// 3x3 ana köşegen blokları bağımsız olduğundan çakışma olmadan rastgele doldur
  void _fillDiagonalBoxes(List<List<int>> grid) {
    for (int i = 0; i < 9; i += 3) {
      _fillBox(grid, i, i);
    }
  }

  void _fillBox(List<List<int>> grid, int row, int col) {
    final numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(_random);
    int numIdx = 0;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        grid[row + r][col + c] = numbers[numIdx++];
      }
    }
  }

  /// Kalan hücreleri rekürsif backtracking ile doldur
  bool _solveGrid(List<List<int>> grid) {
    for (int row = 0; row < 9; row++) {
      for (int col = 0; col < 9; col++) {
        if (grid[row][col] == 0) {
          final numbers = [1, 2, 3, 4, 5, 6, 7, 8, 9]..shuffle(_random);
          for (final num in numbers) {
            if (_isSafe(grid, row, col, num)) {
              grid[row][col] = num;
              if (_solveGrid(grid)) {
                return true;
              }
              grid[row][col] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  bool _isSafe(List<List<int>> grid, int row, int col, int num) {
    // Satır kontrolü
    for (int c = 0; c < 9; c++) {
      if (grid[row][c] == num) return false;
    }

    // Sütun kontrolü
    for (int r = 0; r < 9; r++) {
      if (grid[r][col] == num) return false;
    }

    // 3x3 kutu kontrolü
    final startRow = (row ~/ 3) * 3;
    final startCol = (col ~/ 3) * 3;
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 3; c++) {
        if (grid[startRow + r][startCol + c] == num) return false;
      }
    }

    return true;
  }
}
