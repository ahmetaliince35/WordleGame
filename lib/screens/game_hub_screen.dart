import 'package:flutter/material.dart';
import 'anagram_screen.dart';
import 'cengel_bulmaca_screen.dart';
import 'hangman_screen.dart';
import 'islem_oyunu_screen.dart';
import 'sudoku_screen.dart';
import 'word_builder_screen.dart';
import 'word_search_screen.dart';
import 'wordle_screen.dart';

class GameHubScreen extends StatelessWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const GameHubScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final games = [
      _GameItem(
        title: 'Türkçe Wordle',
        icon: Icons.grid_on_rounded,
        accentColor: const Color(0xFF6AAA64),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => WordleScreen(
                onToggleTheme: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        },
      ),
      _GameItem(
        title: 'Sudoku',
        icon: Icons.grid_3x3_rounded,
        accentColor: const Color(0xFF6366F1),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => SudokuScreen(
                onToggleTheme: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        },
      ),
      _GameItem(
        title: 'Kelime Avı ',
        icon: Icons.manage_search_rounded,
        accentColor: const Color(0xFF10B981),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => WordSearchScreen(
                onToggleTheme: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        },
      ),
      _GameItem(
        title: 'Matematiksel Bulmaca',
        icon: Icons.calculate_rounded,
        accentColor: const Color(0xFF0D9488),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => IslemOyunuScreen(
                onToggleTheme: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        },
      ),
      _GameItem(
        title: 'Çengel Bulmaca',
        icon: Icons.grid_4x4_rounded,
        accentColor: const Color(0xFFD97706),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const CengelBulmacaScreen(),
            ),
          );
        },
      ),
      _GameItem(
        title: 'Kelime Türet',
        icon: Icons.spellcheck_rounded,
        accentColor: const Color(0xFF2B82BA),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => WordBuilderScreen(
                onToggleTheme: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        },
      ),
      _GameItem(
        title: 'Adam Asmaca',
        icon: Icons.person_search_rounded,
        accentColor: const Color(0xFFE56A54),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => HangmanScreen(
                onToggleTheme: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        },
      ),
      _GameItem(
        title: 'Kelimeyi Düzelt',
        icon: Icons.shuffle_rounded,
        accentColor: const Color(0xFF7C5CBF),
        isAvailable: true,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => AnagramScreen(
                onToggleTheme: onToggleTheme,
                isDarkMode: isDarkMode,
              ),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.sports_esports_rounded, size: 28),
            SizedBox(width: 10),
            Text(
              'Kelime Oyunları Dünyası',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: 'Temayı Değiştir',
            onPressed: onToggleTheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                      (context, index) {
                    final game = games[index];
                    return _buildGameCard(context, game);
                  },
                  childCount: games.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, _GameItem game) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: game.isAvailable
              ? const Color(0xFF6AAA64).withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: game.isAvailable
              ? game.onTap
              : () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${game.title} çok yakında eklenecektir!'),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: game.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(game.icon, color: game.accentColor, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  game.isAvailable
                      ? Icons.play_arrow_rounded
                      : Icons.lock_outline_rounded,
                  color: game.isAvailable
                      ? const Color(0xFF6AAA64)
                      : theme.disabledColor,
                  size: 28,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameItem {
  final String title;
  final IconData icon;
  final Color accentColor;
  final bool isAvailable;
  final VoidCallback? onTap;

  _GameItem({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.isAvailable,
    this.onTap,
  });
}