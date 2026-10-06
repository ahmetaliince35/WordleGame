import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LengthSelector extends StatelessWidget {
  final int selectedLength;
  final ValueChanged<int> onLengthChanged;
  final bool isGameInProgress;

  const LengthSelector({
    super.key,
    required this.selectedLength,
    required this.onLengthChanged,
    this.isGameInProgress = false,
  });

  static const List<int> lengths = [4, 5, 6, 7];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? GameColors.darkSurface : const Color(0xFFEAEFF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: lengths.map((length) {
          final isSelected = length == selectedLength;

          return GestureDetector(
            onTap: () {
              if (isSelected) return;
              if (isGameInProgress) {
                // If game in progress, show prompt or confirm
                _confirmSwitch(context, length);
              } else {
                onLengthChanged(length);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? GameColors.correctDark : GameColors.correctLight)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                '$length Harf',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _confirmSwitch(BuildContext context, int newLength) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Yeni Oyuna Başla?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Mevcut $selectedLength harfli oyun sonlandırılıp $newLength harfli yeni oyun başlatılacak. Devam etmek istiyor musunuz?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onLengthChanged(newLength);
            },
            child: const Text('Yeni Oyun Başlat'),
          ),
        ],
      ),
    );
  }
}
