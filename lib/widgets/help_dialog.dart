import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? GameColors.darkSurface : GameColors.lightSurface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Nasıl Oynanır?',
                    style: TextStyle(
                      fontSize: 19,
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
              const SizedBox(height: 14),
              Text(
                '• Gizli Türkçe kelimeyi 6 denemede tahmin etmeye çalışın.\n'
                '• Her tahmin geçerli bir Türkçe sözlük kelimesi olmalıdır.\n'
                '• 4, 5, 6 veya 7 harfli modlar arasında dilediğiniz gibi geçiş yapabilirsiniz.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: isDark ? GameColors.darkBorder : GameColors.lightBorder),
              const SizedBox(height: 12),
              Text(
                'RENK ANLAMLARI',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                  color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 12),

              _buildExample(
                char: 'K',
                bg: isDark ? GameColors.correctDark : GameColors.correctLight,
                description: 'Yeşil ton: Harf kelimede var ve DOĞRU yerde.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              _buildExample(
                char: 'A',
                bg: isDark ? GameColors.presentDark : GameColors.presentLight,
                description: 'Sıcak bal/kum tonu: Harf kelimede var ama YANLIŞ yerde.',
                isDark: isDark,
              ),
              const SizedBox(height: 10),

              _buildExample(
                char: 'L',
                bg: isDark ? GameColors.absentDark : GameColors.absentLight,
                description: 'Gri ton: Harf kelimede YOK.',
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: isDark ? GameColors.correctDark : GameColors.correctLight,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Anladım, Oyna!'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExample({
    required String char,
    required Color bg,
    required String description,
    required bool isDark,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            char,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
