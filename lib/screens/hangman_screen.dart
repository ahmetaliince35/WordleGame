import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/letter_state.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/virtual_keyboard.dart';

class HangmanScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const HangmanScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<HangmanScreen> createState() => _HangmanScreenState();
}

class _HangmanScreenState extends State<HangmanScreen> {
  static const int maxLives = 6;

  bool _isLoading = true;
  String? _errorMessage;

  WordData? _currentWordData;
  final Set<String> _guessedLetters = {};
  final Map<String, LetterStatus> _keyboardStatuses = {};
  int _wrongGuesses = 0;
  bool _isGameOver = false;
  bool _isWon = false;
  bool _showHint = false;

  int _streak = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  Future<void> _startNewGame() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _guessedLetters.clear();
      _keyboardStatuses.clear();
      _wrongGuesses = 0;
      _isGameOver = false;
      _isWon = false;
      _showHint = false;
    });

    try {
      final db = DatabaseService();
      await db.initialize();
      // Harf sınırı olmaksızın her türden kelime veya boşluklu tamlama
      final word = await db.getRandomHangmanWord();

      if (mounted) {
        setState(() {
          _currentWordData = word;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _onLetterTap(String letter) {
    if (_isGameOver || _isLoading || _guessedLetters.contains(letter)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _guessedLetters.add(letter);
      final word = _currentWordData!.word;

      if (!word.contains(letter)) {
        _keyboardStatuses[letter] = LetterStatus.absent;
        _wrongGuesses++;
        if (_wrongGuesses >= maxLives) {
          _isGameOver = true;
          _isWon = false;
          _streak = 0;
          _showGameOverModal(isWin: false);
        }
      } else {
        _keyboardStatuses[letter] = LetterStatus.correct;
        // Kelimedeki tüm harflerin (boşluklar hariç) bilinip bilinmediğini kontrol et
        final allGuessed = word.split('').every((ch) => ch == ' ' || _guessedLetters.contains(ch));
        if (allGuessed) {
          _isGameOver = true;
          _isWon = true;
          _streak++;
          _showGameOverModal(isWin: true);
        }
      }
    });
  }

  void _showGameOverModal({required bool isWin}) {
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      final isDark = widget.isDarkMode;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: isDark ? GameColors.darkSurface : GameColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(
            children: [
              Icon(
                isWin ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
                size: 48,
                color: isWin ? const Color(0xFF6AAA64) : Colors.redAccent,
              ),
              const SizedBox(height: 10),
              Text(
                isWin ? 'Tebrikler! Kazandınız!' : 'Oyun Bitti!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                _currentWordData?.word ?? '',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: isWin ? const Color(0xFF6AAA64) : Colors.redAccent,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E232A) : const Color(0xFFF1F4F8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFFC9B458)),
                        const SizedBox(width: 6),
                        Text(
                          'TDK Anlamı',
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
                      _currentWordData?.meaning ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _startNewGame();
              },
              icon: const Icon(Icons.replay_rounded),
              label: const Text('Yeni Kelime'),
              style: FilledButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF538D4E) : const Color(0xFF6AAA64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final remainingLives = maxLives - _wrongGuesses;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Adam Asmaca',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: 'Temayı Değiştir',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yeni Oyun',
            onPressed: _startNewGame,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: isDark ? GameColors.correctDark : GameColors.correctLight,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Kelime hazırlanıyor...',
                      style: TextStyle(
                        color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.amber),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _startNewGame,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      const SizedBox(height: 8),

                      // Lives & Streak Indicators
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              // Hearts
                              Row(
                                children: List.generate(maxLives, (index) {
                                  final isAlive = index < remainingLives;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 3.0),
                                    child: Icon(
                                      isAlive ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                      size: 22,
                                      color: isAlive ? const Color(0xFFE56A54) : Colors.grey.withValues(alpha: 0.5),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(width: 20),
                              // Streak
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6AAA64).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFF6AAA64)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Seri: $_streak',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: Color(0xFF6AAA64),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Hangman Canvas & Word Blanks Area (Responsive and overflow-free)
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final availH = constraints.maxHeight;
                            final availW = constraints.maxWidth;
                            final canvasH = (availH * 0.38).clamp(80.0, 140.0);
                            final canvasW = canvasH * 1.15;

                            return SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(height: (availH * 0.01).clamp(2.0, 8.0)),

                                  // Hangman Canvas Drawing
                                  Center(
                                    child: CustomPaint(
                                      size: Size(canvasW, canvasH),
                                      painter: _HangmanPainter(
                                        wrongCount: _wrongGuesses,
                                        isDark: isDark,
                                      ),
                                    ),
                                  ),

                                  SizedBox(height: (availH * 0.02).clamp(4.0, 10.0)),

                                  // Hint Box (TDK Definition) or Hint Button
                                  if (_showHint && _currentWordData != null)
                                    Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF282E37) : const Color(0xFFF1F4F8),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: const Color(0xFFC9B458).withValues(alpha: 0.5),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFC9B458)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _currentWordData!.meaning,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12.0,
                                                color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  else
                                    TextButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _showHint = true;
                                        });
                                      },
                                      icon: const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFC9B458)),
                                      label: const Text(
                                        'İpucu Göster (TDK Anlamı)',
                                        style: TextStyle(color: Color(0xFFC9B458), fontSize: 13, fontWeight: FontWeight.w600),
                                      ),
                                    ),

                                  SizedBox(height: (availH * 0.02).clamp(4.0, 12.0)),

                                  // Word Blanks
                                  _buildWordBlanks(_currentWordData?.word ?? '', isDark, availW),

                                  const SizedBox(height: 6),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      // Virtual Keyboard (Q Türkçe Klavye - Action Bar gizli)
                      VirtualKeyboard(
                        letterStatuses: _keyboardStatuses,
                        onKeyPressed: _onLetterTap,
                        onEnterPressed: () {},
                        onDeletePressed: () {},
                        showActionBar: false,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildWordBlanks(String word, bool isDark, double maxAvailableWidth) {
    if (word.isEmpty) return const SizedBox.shrink();

    // Boşluklara göre kelimelere böl (Çok kelimeli tamlamalar için alt satıra geçiş sağlar)
    final words = word.split(' ');
    final contentWidth = (maxAvailableWidth - 16.0).clamp(100.0, 1000.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10.0, // Kelimeler arası belirgin boşluk
        runSpacing: 8.0, // Satır arası boşluk
        children: words.map((w) {
          return _buildWordToken(w, isDark, contentWidth);
        }).toList(),
      ),
    );
  }

  Widget _buildWordToken(String wordToken, bool isDark, double maxContainerWidth) {
    final totalChars = wordToken.length;
    if (totalChars == 0) return const SizedBox.shrink();

    // Harf kutusu boyutu kelimenin uzunluğuna ve ekran genişliğine göre matematiksel olarak hesaplanır
    final marginH = totalChars >= 12 ? 1.0 : (totalChars >= 8 ? 1.5 : 2.0);
    final totalMargin = totalChars * marginH * 2;

    double boxWidth = (maxContainerWidth - totalMargin) / totalChars;
    boxWidth = boxWidth.clamp(16.0, 36.0);

    final boxHeight = (boxWidth * 1.25).clamp(24.0, 46.0);
    final fontSize = (boxWidth * 0.55).clamp(10.5, 20.0);

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContainerWidth),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: wordToken.split('').map((char) {
            final isGuessed = _guessedLetters.contains(char);
            final isRevealedOnLoss = _isGameOver && !_isWon;
            final showChar = isGuessed || isRevealedOnLoss;

            return Container(
              width: boxWidth,
              height: boxHeight,
              margin: EdgeInsets.symmetric(horizontal: marginH),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark ? GameColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(boxWidth < 22 ? 5 : 8),
                border: Border.all(
                  color: isGuessed
                      ? const Color(0xFF438A4A)
                      : (isRevealedOnLoss
                          ? const Color(0xFFE56A54)
                          : (isDark ? GameColors.darkBorder : GameColors.lightBorder)),
                  width: (isGuessed || isRevealedOnLoss) ? 2.0 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                showChar ? char : '',
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: isRevealedOnLoss && !isGuessed
                      ? const Color(0xFFE56A54)
                      : (isDark ? Colors.white : const Color(0xFF1A1A1B)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _HangmanPainter extends CustomPainter {
  final int wrongCount;
  final bool isDark;

  _HangmanPainter({required this.wrongCount, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = (h / 38.0).clamp(2.0, 3.5);
    final gallowsPaint = Paint()
      ..color = isDark ? const Color(0xFF718096) : const Color(0xFF878A8C)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final bodyPaint = Paint()
      ..color = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF2D3748)
      ..strokeWidth = stroke * 0.9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Taban çizgisi
    final groundY = h * 0.92;
    final poleX = w * 0.28;
    final topY = h * 0.10;
    final ropeX = w * 0.72;
    final ropeEndY = h * 0.24;

    canvas.drawLine(Offset(w * 0.08, groundY), Offset(w * 0.92, groundY), gallowsPaint);
    canvas.drawLine(Offset(poleX, groundY), Offset(poleX, topY), gallowsPaint);
    canvas.drawLine(Offset(poleX, topY), Offset(ropeX, topY), gallowsPaint);
    canvas.drawLine(Offset(ropeX, topY), Offset(ropeX, ropeEndY), gallowsPaint);
    canvas.drawLine(Offset(poleX, topY + h * 0.16), Offset(poleX + w * 0.18, topY), gallowsPaint);

    final headRadius = (h * 0.095).clamp(8.0, 15.0);
    final headCenterY = ropeEndY + headRadius;
    final bodyStartY = headCenterY + headRadius;
    final bodyEndY = bodyStartY + (h * 0.23);

    if (wrongCount >= 1) {
      // Baş
      canvas.drawCircle(Offset(ropeX, headCenterY), headRadius, bodyPaint);
    }
    if (wrongCount >= 2) {
      // Gövde
      canvas.drawLine(Offset(ropeX, bodyStartY), Offset(ropeX, bodyEndY), bodyPaint);
    }
    if (wrongCount >= 3) {
      // Sol Kol
      canvas.drawLine(
        Offset(ropeX, bodyStartY + (bodyEndY - bodyStartY) * 0.25),
        Offset(ropeX - w * 0.12, bodyStartY + (bodyEndY - bodyStartY) * 0.70),
        bodyPaint,
      );
    }
    if (wrongCount >= 4) {
      // Sağ Kol
      canvas.drawLine(
        Offset(ropeX, bodyStartY + (bodyEndY - bodyStartY) * 0.25),
        Offset(ropeX + w * 0.12, bodyStartY + (bodyEndY - bodyStartY) * 0.70),
        bodyPaint,
      );
    }
    if (wrongCount >= 5) {
      // Sol Bacak
      canvas.drawLine(
        Offset(ropeX, bodyEndY),
        Offset(ropeX - w * 0.11, bodyEndY + (h * 0.17)),
        bodyPaint,
      );
    }
    if (wrongCount >= 6) {
      // Sağ Bacak
      canvas.drawLine(
        Offset(ropeX, bodyEndY),
        Offset(ropeX + w * 0.11, bodyEndY + (h * 0.17)),
        bodyPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HangmanPainter oldDelegate) {
    return oldDelegate.wrongCount != wrongCount || oldDelegate.isDark != isDark;
  }
}
