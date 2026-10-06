import 'dart:math';
import 'package:flutter/material.dart';
import '../models/game_stats.dart';
import '../theme/app_theme.dart';

class StatsDialog extends StatelessWidget {
  final GameStats stats;
  final int wordLength;

  const StatsDialog({
    super.key,
    required this.stats,
    required this.wordLength,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final maxGuesses = stats.guessDistribution.values.fold(0, (maxVal, val) => max(maxVal, val));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? GameColors.darkSurface : GameColors.lightSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'İstatistikler ($wordLength Harfli)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Top Stat numbers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Oynanan', '${stats.played}', isDark),
                _buildStatItem('Kazanma', '%${stats.winPercentage}', isDark),
                _buildStatItem('Mevcut Seri', '${stats.currentStreak}', isDark),
                _buildStatItem('En İyi Seri', '${stats.maxStreak}', isDark),
              ],
            ),
            const SizedBox(height: 24),

            Text(
              'TAHMİN DAĞILIMI',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Guess distribution bars
            ...List.generate(6, (index) {
              final guessNum = index + 1;
              final count = stats.guessDistribution[guessNum] ?? 0;
              final percentage = maxGuesses > 0 ? (count / maxGuesses) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text(
                        '$guessNum',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 20,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E232A) : const Color(0xFFEEF1F5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: percentage == 0 ? 0.07 : percentage,
                            child: Container(
                              height: 20,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(
                                color: count > 0
                                    ? (isDark ? GameColors.correctDark : GameColors.correctLight)
                                    : (isDark ? const Color(0xFF333B46) : const Color(0xFFD0D7DE)),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}
