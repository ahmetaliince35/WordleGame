class GameStats {
  final int played;
  final int won;
  final int currentStreak;
  final int maxStreak;
  final Map<int, int> guessDistribution;

  const GameStats({
    this.played = 0,
    this.won = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.guessDistribution = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0},
  });

  int get winPercentage => played == 0 ? 0 : ((won / played) * 100).round();

  GameStats copyWith({
    int? played,
    int? won,
    int? currentStreak,
    int? maxStreak,
    Map<int, int>? guessDistribution,
  }) {
    return GameStats(
      played: played ?? this.played,
      won: won ?? this.won,
      currentStreak: currentStreak ?? this.currentStreak,
      maxStreak: maxStreak ?? this.maxStreak,
      guessDistribution: guessDistribution ?? this.guessDistribution,
    );
  }
}
