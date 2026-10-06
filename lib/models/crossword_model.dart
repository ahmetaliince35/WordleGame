enum CrosswordDirection {
  across, // Soldan Sağa
  down,   // Yukarıdan Aşağı
}

class CrosswordClue {
  final int id;
  final String word;
  final String clue;
  final CrosswordDirection direction;
  final int startRow;
  final int startCol;
  final int length;

  const CrosswordClue({
    required this.id,
    required this.word,
    required this.clue,
    required this.direction,
    required this.startRow,
    required this.startCol,
    required this.length,
  });

  int getRowForIndex(int i) =>
      direction == CrosswordDirection.across ? startRow : startRow + i;

  int getColForIndex(int i) =>
      direction == CrosswordDirection.across ? startCol + i : startCol;
}

class CrosswordCell {
  final int row;
  final int col;
  final String correctChar;
  String enteredChar;
  bool isRevealedByHint;
  int? clueNumber;
  final List<int> clueIds;

  CrosswordCell({
    required this.row,
    required this.col,
    required this.correctChar,
    this.enteredChar = '',
    this.isRevealedByHint = false,
    this.clueNumber,
    required this.clueIds,
  });

  bool get isCorrect =>
      enteredChar.isNotEmpty &&
      enteredChar.toUpperCase() == correctChar.toUpperCase();
}

class CrosswordPuzzle {
  final String id;
  final String title;
  final int rows;
  final int cols;
  final List<CrosswordClue> clues;

  const CrosswordPuzzle({
    required this.id,
    required this.title,
    required this.rows,
    required this.cols,
    required this.clues,
  });
}
