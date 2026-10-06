enum LetterStatus {
  empty,
  pending,
  absent,
  present,
  correct,
}

class TileData {
  final String char;
  final LetterStatus status;

  const TileData({
    this.char = '',
    this.status = LetterStatus.empty,
  });

  TileData copyWith({
    String? char,
    LetterStatus? status,
  }) {
    return TileData(
      char: char ?? this.char,
      status: status ?? this.status,
    );
  }
}

class WordData {
  final String word;
  final String meaning;
  final int length;

  const WordData({
    required this.word,
    required this.meaning,
    required this.length,
  });
}
