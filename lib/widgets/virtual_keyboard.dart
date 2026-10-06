import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/letter_state.dart';

class VirtualKeyboard extends StatelessWidget {
  final Map<String, LetterStatus> letterStatuses;
  final ValueChanged<String> onKeyPressed;
  final VoidCallback onEnterPressed;
  final VoidCallback onDeletePressed;
  final bool showActionBar;

  const VirtualKeyboard({
    super.key,
    required this.letterStatuses,
    required this.onKeyPressed,
    required this.onEnterPressed,
    required this.onDeletePressed,
    this.showActionBar = true,
  });

  // Orijinal Türkçe Q Klavye (Q, W, X dahil)
  static const List<String> _row1 = ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'];
  static const List<String> _row2 = ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'];
  static const List<String> _row3 = ['Z', 'X', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç'];

  void _triggerHaptic() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      // Ekranın yan kenarlarından minimum boşluk (maksimum tuş yüzeyi)
      padding: EdgeInsets.fromLTRB(2, 2, 2, bottomInset > 0 ? bottomInset + 2 : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Üst Eylem Barı: SİL & GİRİŞ (Harflerin üstünde, kolay erişilebilir ve yazımı engellemez)
          if (showActionBar) ...[
            _buildTopActionBar(context),
            const SizedBox(height: 6),
          ],

          // 1. Sıra (12 Harf - Tam Genişlik)
          _buildLetterRow(_row1, context),
          const SizedBox(height: 5),

          // 2. Sıra (11 Harf)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: _buildLetterRow(_row2, context),
          ),
          const SizedBox(height: 5),

          // 3. Sıra (9 Harf - Geniş ve İri Tuşlar)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: _buildLetterRow(_row3, context),
          ),
        ],
      ),
    );
  }

  Widget _buildTopActionBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        children: [
          // SİL Tuşu (Geniş, ergonomik ve belirgin)
          Expanded(
            flex: 4,
            child: _buildActionButton(
              icon: Icons.backspace_rounded,
              label: 'SİL',
              bgColor: isDark ? const Color(0xFF4A5568) : const Color(0xFF7E8896),
              textColor: Colors.white,
              onTap: () {
                _triggerHaptic();
                onDeletePressed();
              },
            ),
          ),
          const SizedBox(width: 8),

          // GİRİŞ / ONAYLA Tuşu (Geniş, güven veren yeşil ton)
          Expanded(
            flex: 5,
            child: _buildActionButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'GİRİŞ',
              bgColor: isDark ? const Color(0xFF438A4A) : const Color(0xFF539E59),
              textColor: Colors.white,
              onTap: () {
                _triggerHaptic();
                onEnterPressed();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterRow(List<String> keys, BuildContext context) {
    return Row(
      children: keys.map((key) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: _buildKey(key, context),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            offset: const Offset(0, 2),
            blurRadius: 1,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: 21),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(String char, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = letterStatuses[char] ?? LetterStatus.empty;

    Color bg;
    Color textColor;
    Color borderBottomColor;

    switch (status) {
      case LetterStatus.correct:
        bg = isDark ? const Color(0xFF438A4A) : const Color(0xFF5BA661);
        textColor = Colors.white;
        borderBottomColor = const Color(0xFF326B38);
        break;
      case LetterStatus.present:
        bg = isDark ? const Color(0xFFB59F3B) : const Color(0xFFC9B458);
        textColor = Colors.white;
        borderBottomColor = const Color(0xFF8A7724);
        break;
      case LetterStatus.absent:
        bg = isDark ? const Color(0xFF383C42) : const Color(0xFF7E848C);
        textColor = Colors.white.withValues(alpha: 0.95);
        borderBottomColor = isDark ? const Color(0xFF232529) : const Color(0xFF5A5F66);
        break;
      default:
        bg = isDark ? const Color(0xFF6B7280) : const Color(0xFFD6DBE1);
        textColor = isDark ? Colors.white : const Color(0xFF1E242B);
        borderBottomColor = isDark ? const Color(0xFF4B525D) : const Color(0xFFA6ACB5);
        break;
    }

    return Container(
      // Tuş boyu ferah 56 piksel (parmakla kolay basılır)
      height: 56,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: borderBottomColor.withValues(alpha: 0.5),
            offset: const Offset(0, 2),
            blurRadius: 0.5,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: () {
            _triggerHaptic();
            onKeyPressed(char);
          },
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.0),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  char,
                  style: TextStyle(
                    fontSize: 21.0,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}