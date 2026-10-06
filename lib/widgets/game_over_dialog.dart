import 'package:flutter/material.dart';
import '../models/letter_state.dart';
import '../theme/app_theme.dart';

class GameOverDialog extends StatelessWidget {
  final bool isWin;
  final WordData wordData;
  final int attemptsUsed;
  final VoidCallback onPlayAgain;

  const GameOverDialog({
    super.key,
    required this.isWin,
    required this.wordData,
    required this.attemptsUsed,
    required this.onPlayAgain,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? GameColors.darkSurface : GameColors.lightSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status Icon & Title
            Icon(
              isWin ? Icons.check_circle_outline_rounded : Icons.sentiment_dissatisfied_rounded,
              size: 52,
              color: isWin
                  ? (isDark ? GameColors.correctDark : GameColors.correctLight)
                  : (isDark ? GameColors.presentDark : GameColors.presentLight),
            ),
            const SizedBox(height: 12),
            Text(
              isWin ? 'Tebrikler!' : 'Bu Sefer Olmadı',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isWin ? '$attemptsUsed. denemede buldunuz.' : 'Tüm deneme haklarınız bitti.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Target Word Box
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isDark
                    ? GameColors.darkBackground
                    : GameColors.lightBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? GameColors.darkBorder : GameColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'GİZLİ KELİME',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    wordData.word,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                      color: isDark ? GameColors.correctDark : GameColors.correctLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // TDK Meaning Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222830) : const Color(0xFFF1F4F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.menu_book_rounded,
                        size: 16,
                        color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'TDK Sözlük Anlamı',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    wordData.meaning,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: BorderSide(
                        color: isDark ? GameColors.darkBorder : GameColors.lightBorder,
                      ),
                    ),
                    child: Text(
                      'Panoyu İncele',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onPlayAgain();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: isDark ? GameColors.correctDark : GameColors.correctLight,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'Yeni Kelime',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
