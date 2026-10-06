import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/letter_state.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class AnagramScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const AnagramScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<AnagramScreen> createState() => _AnagramScreenState();
}

class _AnagramScreenState extends State<AnagramScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String? _errorMessage;

  WordData? _currentWordData;
  List<String> _scrambledPool = [];
  final List<int> _placedPoolIndices = [];

  bool _isSuccess = false;
  int _streak = 0;
  int _score = 0;
  int _level = 1; // 1: 4 Harf, 2: 5 Harf, 3: 6 Harf, 4: 7 Harf
  int _solvedInCurrentLevel = 0; // 0/3
  bool _showDefinition = false;
  String? _toastMessage;
  int _hintLettersCount = 0;

  int get _wordLengthForLevel => switch (_level) {
        1 => 4,
        2 => 5,
        3 => 6,
        _ => 7,
      };

  double get _multiplier {
    if (_streak >= 6) return 2.5;
    if (_streak >= 3) return 2.0;
    if (_streak >= 1) return 1.5;
    return 1.0;
  }

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -3), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));

    _startNewAnagram();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _startNewAnagram() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _placedPoolIndices.clear();
      _isSuccess = false;
      _showDefinition = false;
      _toastMessage = null;
      _hintLettersCount = 0;
    });

    try {
      final db = DatabaseService();
      await db.initialize();
      // Seviyeye göre hedef kelime uzunluğu (4, 5, 6, 7 harf)
      final len = _wordLengthForLevel;
      final wordData = await db.getRandomWord(len);

      // Scramble letters until different from original
      List<String> scrambled = wordData.word.split('');
      int attempts = 0;
      while (scrambled.join() == wordData.word && attempts < 10) {
        scrambled.shuffle(Random());
        attempts++;
      }

      if (mounted) {
        setState(() {
          _currentWordData = wordData;
          _scrambledPool = scrambled;
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

  void _useLetterHint() {
    if (_isSuccess || _currentWordData == null) return;
    final target = _currentWordData!.word;
    final nextSlot = _placedPoolIndices.length;
    if (nextSlot >= target.length) return;

    final targetChar = target[nextSlot];
    // Havuzdaki henüz yerleştirilmemiş doğru harfi bul
    int foundIndex = -1;
    for (int i = 0; i < _scrambledPool.length; i++) {
      if (!_placedPoolIndices.contains(i) && _scrambledPool[i] == targetChar) {
        foundIndex = i;
        break;
      }
    }

    if (foundIndex != -1) {
      HapticFeedback.lightImpact();
      setState(() {
        _hintLettersCount++;
        _streak = 0; // İpucu harfi açıldığında kombo kırılır
        _placedPoolIndices.add(foundIndex);
      });
      _showToast('İpucu: "$targetChar" yerleştirildi (-15 puan ceza)');
      if (_placedPoolIndices.length == _scrambledPool.length) {
        _checkAnswer();
      }
    }
  }

  void _onPoolTileTap(int poolIndex) {
    if (_isSuccess || _placedPoolIndices.contains(poolIndex)) return;

    HapticFeedback.lightImpact();
    setState(() {
      _placedPoolIndices.add(poolIndex);
    });

    // Automatically check when full
    if (_placedPoolIndices.length == _scrambledPool.length) {
      _checkAnswer();
    }
  }

  void _onAnswerSlotTap(int position) {
    if (_isSuccess || position >= _placedPoolIndices.length) return;

    HapticFeedback.lightImpact();
    setState(() {
      _placedPoolIndices.removeAt(position);
    });
  }

  void _onClear() {
    if (_isSuccess || _placedPoolIndices.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _placedPoolIndices.clear();
    });
  }

  void _onShufflePool() {
    if (_isSuccess) return;
    HapticFeedback.mediumImpact();
    setState(() {
      if (_placedPoolIndices.isEmpty) {
        // Hiç harf yerleştirilmemişse tüm havuzu karıştır
        _scrambledPool.shuffle(Random());
      } else if (_placedPoolIndices.length == _scrambledPool.length) {
        // Tüm harfler yerleştirilmişse geri al ve karıştır
        _placedPoolIndices.clear();
        _scrambledPool.shuffle(Random());
      } else {
        // Yerleştirilmemiş harfleri karıştır
        final unplacedIndices = <int>[];
        final unplacedLetters = <String>[];
        for (int i = 0; i < _scrambledPool.length; i++) {
          if (!_placedPoolIndices.contains(i)) {
            unplacedIndices.add(i);
            unplacedLetters.add(_scrambledPool[i]);
          }
        }
        unplacedLetters.shuffle(Random());
        for (int i = 0; i < unplacedIndices.length; i++) {
          _scrambledPool[unplacedIndices[i]] = unplacedLetters[i];
        }
      }
    });
  }

  Future<void> _checkAnswer() async {
    final guessedWord = _placedPoolIndices.map((i) => _scrambledPool[i]).join();
    final target = _currentWordData!.word;

    // Direct match or valid anagram check
    final isMatch = guessedWord == target;
    final db = DatabaseService();
    final isValidAnagram = !isMatch && await db.isValidWord(guessedWord, guessedWord.length);

    if (isMatch || isValidAnagram) {
      HapticFeedback.heavyImpact();
      final totalLetters = guessedWord.length;
      final isAllHinted = _hintLettersCount >= totalLetters;

      int earnedPts = 0;
      if (isAllHinted) {
        // Tüm harfler ipucu ile açılmışsa: Ekstra puan kazanılmaz, 0 puan verilir
        earnedPts = 0;
      } else {
        // Harf başına 20 taban puan, açılan her ipucu harfi için -15 ceza
        final basePts = totalLetters * 20;
        final penalty = _hintLettersCount * 15;
        final netPts = (basePts - penalty).clamp(0, basePts);
        final multiplier = _hintLettersCount > 0 ? 1.0 : _multiplier;
        earnedPts = (netPts * multiplier).round();
      }

      setState(() {
        _isSuccess = true;
        _score += earnedPts;

        if (_hintLettersCount == 0) {
          _streak++;
        } else {
          _streak = 0; // İpucu kullanıldıysa kombo sıfırlanır
        }

        // Yalnızca oyuncu kendi katkısıyla çözdüyse seviye ilerlemesi sayılır
        if (!isAllHinted) {
          _solvedInCurrentLevel++;
          if (_solvedInCurrentLevel >= 3) {
            if (_level < 4) {
              _level++;
              _solvedInCurrentLevel = 0;
              _showToast('Tebrikler! Seviye $_level seviyesine yükseldiniz!');
            }
          }
        }
      });

      if (isAllHinted) {
        _showToast('Tüm harfler ipucuyla açıldı (0 Puan)');
      } else if (_hintLettersCount > 0) {
        _showToast('+$earnedPts Puan ($_hintLettersCount harf ipucu cezası)');
      } else {
        final comboText = _multiplier > 1.0 ? "${_multiplier}x Kombo!" : "Harika!";
        _showToast('+$earnedPts Puan! $comboText');
      }
    } else {
      HapticFeedback.vibrate();
      _shakeController.forward(from: 0.0);
      setState(() {
        _streak = 0; // Kombo sıfırlanır
        _placedPoolIndices.clear(); // Yanlış girildikten sonra otomatik temizlensin
      });
      _showToast('Kelime doğru değil. Tekrar deneyin.');
    }
  }


  void _showToast(String msg) {
    setState(() {
      _toastMessage = msg;
    });
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _toastMessage == msg) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Anagram Çözücü',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          // Harf Aç Butonu (Kompakt ve taşmayan)
          IconButton(
            icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFD4AF37)),
            tooltip: 'Harf Aç (-15 Puan)',
            onPressed: _useLetterHint,
          ),
          // TDK Anlam Göster Butonu
          IconButton(
            icon: Icon(
              _showDefinition ? Icons.menu_book_rounded : Icons.menu_book_outlined,
              color: _showDefinition ? const Color(0xFFD4AF37) : null,
            ),
            tooltip: 'TDK Anlamını Göster/Gizle',
            onPressed: () {
              setState(() {
                _showDefinition = !_showDefinition;
              });
            },
          ),
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            tooltip: 'Temayı Değiştir',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sonraki Kelime',
            onPressed: _startNewAnagram,
          ),
          const SizedBox(width: 4),
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
                      'Anagram hazırlanıyor...',
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
                            onPressed: _startNewAnagram,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 4),

                            // Header Score & Level Badges
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBadge(
                                    label: 'Seviye $_level',
                                    value: '$_solvedInCurrentLevel/3',
                                    color: const Color(0xFF2B82BA),
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildBadge(
                                    label: 'Kombo',
                                    value: '${_multiplier}x',
                                    color: Colors.deepPurpleAccent,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  _buildBadge(
                                    label: 'Puan',
                                    value: '$_score',
                                    color: const Color(0xFF438A4A),
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                          // TDK Hint Box (Açılır / Kapanır)
                          if (_currentWordData != null && _showDefinition && !_isSuccess)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? GameColors.darkSurface : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFC9B458).withValues(alpha: 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.lightbulb_rounded, color: Color(0xFFC9B458), size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'TDK Sözlük İpucu',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1.0,
                                            color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _currentWordData!.meaning,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            height: 1.35,
                                            color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 20),

                          // Answer Word Slots (Shakable on wrong answer)
                          AnimatedBuilder(
                            animation: _shakeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(_shakeAnimation.value, 0),
                                child: child,
                              );
                            },
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_scrambledPool.length, (slotIdx) {
                                final isFilled = slotIdx < _placedPoolIndices.length;
                                final char = isFilled ? _scrambledPool[_placedPoolIndices[slotIdx]] : '';

                                return GestureDetector(
                                  onTap: () => _onAnswerSlotTap(slotIdx),
                                  child: Container(
                                    width: _scrambledPool.length >= 7 ? 40.0 : (_scrambledPool.length >= 6 ? 44.0 : 48.0),
                                    height: _scrambledPool.length >= 7 ? 48.0 : (_scrambledPool.length >= 6 ? 52.0 : 56.0),
                                    margin: EdgeInsets.symmetric(horizontal: _scrambledPool.length >= 7 ? 2.5 : 3.5),
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isFilled
                                          ? (_isSuccess
                                              ? const Color(0xFF6AAA64)
                                              : (isDark ? const Color(0xFF3B4350) : const Color(0xFFD3D6DA)))
                                          : (isDark ? GameColors.darkSurface : Colors.white),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isFilled
                                            ? Colors.transparent
                                            : (isDark ? GameColors.darkBorder : GameColors.lightBorder),
                                        width: 1.5,
                                      ),
                                      boxShadow: isFilled
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      char,
                                      style: TextStyle(
                                        fontSize: _scrambledPool.length >= 7 ? 18.0 : (_scrambledPool.length >= 6 ? 20.0 : 22.0),
                                        fontWeight: FontWeight.w800,
                                        color: isFilled
                                            ? (_isSuccess
                                                ? Colors.white
                                                : (isDark ? Colors.white : const Color(0xFF1A1A1B)))
                                            : Colors.transparent,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),

                          const SizedBox(height: 18),

                          if (_isSuccess) ...[
                            // Başarılı çözüm sonrası TDK Anlam Kartı ve Devam Et Butonu
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E242B) : const Color(0xFFF1F8F1),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF438A4A) : const Color(0xFF6AAA64),
                                        width: 1.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(Icons.check_circle_rounded, color: Color(0xFF6AAA64), size: 20),
                                            const SizedBox(width: 8),
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
                                        const SizedBox(height: 8),
                                        Text(
                                          _currentWordData?.meaning ?? '',
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.4,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: FilledButton.icon(
                                      onPressed: _startNewAnagram,
                                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                                      label: const Text(
                                        'Devam Et',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: isDark ? const Color(0xFF538D4E) : const Color(0xFF6AAA64),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ] else ...[
                            // Action Buttons (Karıştır & Temizle)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _onClear,
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  label: const Text('Temizle'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton.icon(
                                  onPressed: _onShufflePool,
                                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                                  label: const Text('Karıştır'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // Scrambled Letter Tiles Pool
                            Container(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(_scrambledPool.length, (poolIdx) {
                                    final char = _scrambledPool[poolIdx];
                                    final isPlaced = _placedPoolIndices.contains(poolIdx);
                                    final totalChars = _scrambledPool.length;
                                    final tileWidth = totalChars >= 7 ? 40.0 : (totalChars >= 6 ? 44.0 : 48.0);
                                    final tileHeight = totalChars >= 7 ? 48.0 : (totalChars >= 6 ? 52.0 : 56.0);
                                    final marginH = totalChars >= 7 ? 2.5 : 3.5;
                                    final fontSize = totalChars >= 7 ? 18.0 : (totalChars >= 6 ? 20.0 : 22.0);

                                    return Padding(
                                      padding: EdgeInsets.symmetric(horizontal: marginH),
                                      child: GestureDetector(
                                        onTap: () => _onPoolTileTap(poolIdx),
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 150),
                                          width: tileWidth,
                                          height: tileHeight,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isPlaced
                                                ? (isDark ? const Color(0xFF282D36) : const Color(0xFFE2E6EA))
                                                : (isDark ? const Color(0xFF4A5568) : const Color(0xFFB8C2CC)),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: isPlaced
                                                ? []
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 2),
                                                    ),
                                                  ],
                                          ),
                                          child: Text(
                                            char,
                                            style: TextStyle(
                                              fontSize: fontSize,
                                              fontWeight: FontWeight.w800,
                                              color: isPlaced
                                                  ? (isDark ? const Color(0xFF566270) : const Color(0xFFA0AEC0))
                                                  : Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                      // Floating Feedback Toast
                      if (_toastMessage != null)
                        Positioned(
                          top: 48,
                          left: 20,
                          right: 20,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF333B46) : const Color(0xFF2C3539),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Text(
                                _toastMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildBadge({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
