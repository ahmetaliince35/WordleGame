import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_stats.dart';

class StatsService {
  static final StatsService _instance = StatsService._internal();
  factory StatsService() => _instance;
  StatsService._internal();

  static const String _keyPlayed = 'wordle_played_';
  static const String _keyWon = 'wordle_won_';
  static const String _keyCurrentStreak = 'wordle_current_streak_';
  static const String _keyMaxStreak = 'wordle_max_streak_';
  static const String _keyGuessPrefix = 'wordle_guess_dist_';

  Future<GameStats> getStatsForLength(int length) async {
    final prefs = await SharedPreferences.getInstance();
    final played = prefs.getInt('$_keyPlayed$length') ?? 0;
    final won = prefs.getInt('$_keyWon$length') ?? 0;
    final currentStreak = prefs.getInt('$_keyCurrentStreak$length') ?? 0;
    final maxStreak = prefs.getInt('$_keyMaxStreak$length') ?? 0;

    final dist = <int, int>{};
    for (int i = 1; i <= 6; i++) {
      dist[i] = prefs.getInt('$_keyGuessPrefix${length}_$i') ?? 0;
    }

    return GameStats(
      played: played,
      won: won,
      currentStreak: currentStreak,
      maxStreak: maxStreak,
      guessDistribution: dist,
    );
  }

  Future<GameStats> recordGameResult({
    required int length,
    required bool isWin,
    required int attemptsUsed,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final currentStats = await getStatsForLength(length);

    final newPlayed = currentStats.played + 1;
    final newWon = isWin ? currentStats.won + 1 : currentStats.won;
    final newCurrentStreak = isWin ? currentStats.currentStreak + 1 : 0;
    final newMaxStreak = newCurrentStreak > currentStats.maxStreak
        ? newCurrentStreak
        : currentStats.maxStreak;

    final newDist = Map<int, int>.from(currentStats.guessDistribution);
    if (isWin && attemptsUsed >= 1 && attemptsUsed <= 6) {
      newDist[attemptsUsed] = (newDist[attemptsUsed] ?? 0) + 1;
      await prefs.setInt('$_keyGuessPrefix${length}_$attemptsUsed', newDist[attemptsUsed]!);
    }

    await prefs.setInt('$_keyPlayed$length', newPlayed);
    await prefs.setInt('$_keyWon$length', newWon);
    await prefs.setInt('$_keyCurrentStreak$length', newCurrentStreak);
    await prefs.setInt('$_keyMaxStreak$length', newMaxStreak);

    return GameStats(
      played: newPlayed,
      won: newWon,
      currentStreak: newCurrentStreak,
      maxStreak: newMaxStreak,
      guessDistribution: newDist,
    );
  }
}
