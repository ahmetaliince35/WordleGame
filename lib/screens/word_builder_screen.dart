import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class WordBuilderScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const WordBuilderScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<WordBuilderScreen> createState() => _WordBuilderScreenState();
}

class _WordBuilderScreenState extends State<WordBuilderScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  // The 7 letters given for this round (indexed)
  List<String> _rackLetters = [];
  // Tracks which rack letter index is currently selected/placed in word
  final List<int> _selectedRackIndices = [];

  // Words already found in this round with their meanings
  final Map<String, String> _foundWords = {};
  // Tüm türetilebilir geçerli kelimeler listesi
  List<String> _possibleWords = [];

  int _score = 0;
  String? _toastMessage;

  // Hedef Yıldız Puanları
  static const int star1Target = 35;
  static const int star2Target = 75;
  static const int star3Target = 125;

  Map<String, int> _getLetterCounts(String str) {
    final counts = <String, int>{};
    for (final ch in str.split('')) {
      counts[ch] = (counts[ch] ?? 0) + 1;
    }
    return counts;
  }

  bool _canBuild(String word, Map<String, int> rackCounts) {
    final wordCounts = <String, int>{};
    for (final ch in word.split('')) {
      final c = (wordCounts[ch] ?? 0) + 1;
      if (c > (rackCounts[ch] ?? 0)) return false;
      wordCounts[ch] = c;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    _startNewRound();
  }

  Future<void> _startNewRound() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedRackIndices.clear();
      _foundWords.clear();
      _possibleWords.clear();
      _score = 0;
      _toastMessage = null;
    });

    try {
      final db = DatabaseService();
      await db.initialize();
      // 7 harfli rastgele bir temel kelime seç
      final baseWord = await db.getRandomWord(7);
      final letters = baseWord.word.split('')..shuffle(Random());
      final rackCounts = _getLetterCounts(letters.join());

      // Bu harflerden türetilebilecek TÜM geçerli kelimeleri tespit et
      final possible = <String>[];
      for (int len = 3; len <= 7; len++) {
        final wordsForLen = await db.getValidWordsForLength(len);
        for (final w in wordsForLen) {
          if (_canBuild(w, rackCounts)) {
            possible.add(w);
          }
        }
      }

      if (mounted) {
        setState(() {
          _rackLetters = letters;
          _possibleWords = possible;
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

  Future<void> _showWordHint() async {
    final unfound = _possibleWords.where((w) => !_foundWords.containsKey(w)).toList();
    if (unfound.isEmpty) {
      _showToast('Tebrikler! Tüm kelimeleri buldunuz!');
      return;
    }

    HapticFeedback.lightImpact();
    // Rastgele bulunmamış bir kelime seç
    final hintWord = unfound[Random().nextInt(unfound.length)];
    final db = DatabaseService();
    final meaning = await db.getMeaning(hintWord) ?? 'TDK sözlüğünde kayıtlı kelime.';

    _showToast('İpucu (${hintWord.length} Harfli, "${hintWord[0]}..." ile başlar):\n$meaning');
  }

  void _onRackLetterTap(int rackIndex) {
    if (_selectedRackIndices.contains(rackIndex)) {
      // Deselect and remove
      setState(() {
        _selectedRackIndices.remove(rackIndex);
      });
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedRackIndices.add(rackIndex);
      });
    }
  }

  void _onSelectedLetterTap(int atPosition) {
    if (atPosition < _selectedRackIndices.length) {
      setState(() {
        _selectedRackIndices.removeAt(atPosition);
      });
    }
  }

  void _onShuffleRack() {
    HapticFeedback.mediumImpact();
    setState(() {
      if (_selectedRackIndices.isEmpty) {
        _rackLetters.shuffle(Random());
      } else if (_selectedRackIndices.length == _rackLetters.length) {
        // Hepsi seçiliyse önce seçimi temizle, sonra tüm harfleri karıştır
        _selectedRackIndices.clear();
        _rackLetters.shuffle(Random());
      } else {
        // Seçilmeyen harflerin yerlerini karıştır
        final unselectedIndices = <int>[];
        final unselectedLetters = <String>[];
        for (int i = 0; i < _rackLetters.length; i++) {
          if (!_selectedRackIndices.contains(i)) {
            unselectedIndices.add(i);
            unselectedLetters.add(_rackLetters[i]);
          }
        }
        unselectedLetters.shuffle(Random());
        for (int i = 0; i < unselectedIndices.length; i++) {
          _rackLetters[unselectedIndices[i]] = unselectedLetters[i];
        }
      }
    });
  }

  void _onClearWord() {
    if (_selectedRackIndices.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedRackIndices.clear();
      });
    }
  }

  String get _currentWord {
    return _selectedRackIndices.map((idx) => _rackLetters[idx]).join();
  }

  Future<void> _onSubmitWord() async {
    final word = _currentWord;
    if (word.length < 3) {
      _showToast('En az 3 harfli kelime oluşturmalısınız.');
      return;
    }

    if (_foundWords.containsKey(word)) {
      _showToast('Bu kelimeyi zaten buldunuz!');
      return;
    }

    final db = DatabaseService();
    final isValid = await db.isValidWord(word, word.length);

    if (!isValid) {
      _showToast('"$word" sözlükte bulunamadı.');
      return;
    }

    // Valid word found!
    HapticFeedback.mediumImpact();
    final meaning = await db.getMeaning(word) ?? 'TDK sözlüğünde kayıtlı kelime.';

    // Score based on letter count
    final pts = switch (word.length) {
      3 => 10,
      4 => 25,
      5 => 50,
      6 => 80,
      _ => 150, // 7 letters (All letters bonus!)
    };

    setState(() {
      _foundWords[word] = meaning;
      _score += pts;
      _selectedRackIndices.clear();
    });

    _showToast('+$pts Puan! Harika bir kelime.');
  }

  void _showToast(String msg) {
    setState(() {
      _toastMessage = msg;
    });
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _toastMessage == msg) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  void _showWordMeaningDialog(String word, String meaning) {
    final isDark = widget.isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? GameColors.darkSurface : GameColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: Color(0xFFC9B458), size: 24),
            const SizedBox(width: 8),
            Text(
              word,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          meaning,
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  void _showGiveUpDialog() {
    if (_possibleWords.isEmpty) return;

    final isDark = widget.isDarkMode;
    // Kelimeleri harf sayısına göre grupla (7'den 3'e azalan)
    final groupedWords = <int, List<String>>{};
    for (int len = 7; len >= 3; len--) {
      final list = _possibleWords.where((w) => w.length == len).toList()..sort();
      if (list.isNotEmpty) {
        groupedWords[len] = list;
      }
    }

    final totalCount = _possibleWords.length;
    final foundCount = _foundWords.length;
    final unfoundCount = totalCount - foundCount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? GameColors.darkSurface : GameColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sürükleme Tutamacı
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  // Başlık ve İstatistik
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 26),
                      const SizedBox(width: 10),
                      Text(
                        'Tüm Türetilebilir Kelimeler',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toplam $totalCount kelimeden $foundCount tanesini buldunuz ($unfoundCount bulunamadı).',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 10),

                  // Kelime Grupları Listesi
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      children: groupedWords.entries.map((entry) {
                        final length = entry.key;
                        final words = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$length Harfli Kelimeler (${words.length})',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF90CDF4) : const Color(0xFF2B6CB0),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: words.map((w) {
                                  final isFound = _foundWords.containsKey(w);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(10),
                                    onTap: () async {
                                      final meaning = _foundWords[w] ??
                                          await DatabaseService().getMeaning(w) ??
                                          'TDK sözlüğünde kayıtlı kelime.';
                                      if (mounted) {
                                        _showWordMeaningDialog(w, meaning);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isFound
                                            ? (isDark ? const Color(0xFF2E6334) : const Color(0xFFE8F5E9))
                                            : (isDark ? const Color(0xFF2D3748) : const Color(0xFFEDF2F7)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isFound
                                              ? (isDark ? const Color(0xFF438A4A) : const Color(0xFF6AAA64))
                                              : (isDark ? const Color(0xFF4A5568) : const Color(0xFFCBD5E0)),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isFound) ...[
                                            Icon(
                                              Icons.check_rounded,
                                              size: 15,
                                              color: isDark ? Colors.white : const Color(0xFF2E7D32),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Text(
                                            w,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isFound ? FontWeight.w800 : FontWeight.w600,
                                              color: isFound
                                                  ? (isDark ? Colors.white : const Color(0xFF1B5E20))
                                                  : (isDark ? Colors.white70 : const Color(0xFF2D3748)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Alt Butonlar
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Kapat'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _startNewRound();
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Yeni Harfler'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelime Türetmece'),
        actions: [
          // Pes Et Butonu
          TextButton.icon(
            onPressed: _showGiveUpDialog,
            icon: const Icon(Icons.flag_outlined, size: 18, color: Colors.redAccent),
            label: const Text(
              'Pes Et',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
            ),
          ),
          // İpucu Butonu
          TextButton.icon(
            onPressed: _showWordHint,
            icon: const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFD4AF37)),
            label: const Text(
              'İpucu',
              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
            ),
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
            tooltip: 'Yeni Harfler',
            onPressed: _startNewRound,
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
                      'Harfler ve kelimeler taranıyor...',
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
                            onPressed: _startNewRound,
                            child: const Text('Tekrar Dene'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 6),

                          // Header Score & Star Progress
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    _buildBadge(
                                      label: 'Puan',
                                      value: '$_score',
                                      color: const Color(0xFF438A4A),
                                      isDark: isDark,
                                    ),
                                    const Spacer(),
                                    // Yıldız Rozetleri
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.star_rounded,
                                          size: 20,
                                          color: _score >= star1Target ? const Color(0xFFCD7F32) : Colors.grey.shade400,
                                        ),
                                        Icon(
                                          Icons.star_rounded,
                                          size: 20,
                                          color: _score >= star2Target ? const Color(0xFFC0C0C0) : Colors.grey.shade400,
                                        ),
                                        Icon(
                                          Icons.star_rounded,
                                          size: 22,
                                          color: _score >= star3Target ? const Color(0xFFFFD700) : Colors.grey.shade400,
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    _buildBadge(
                                      label: 'Hedef',
                                      value: '${_foundWords.length}/${_possibleWords.length}',
                                      color: const Color(0xFFD97706),
                                      isDark: isDark,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // İlerleme Çubuğu
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (_score / star3Target).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: isDark ? const Color(0xFF333A44) : const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Current Word Assembly Slots
                          Container(
                            height: 64,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? GameColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? GameColors.darkBorder : GameColors.lightBorder,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: _selectedRackIndices.isEmpty
                                ? Center(
                                    child: Text(
                                      'Aşağıdaki harflere dokunarak kelime kurun',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? GameColors.darkTextSecondary
                                            : GameColors.lightTextSecondary,
                                      ),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(_selectedRackIndices.length, (idx) {
                                      final rackIdx = _selectedRackIndices[idx];
                                      final char = _rackLetters[rackIdx];

                                      return GestureDetector(
                                        onTap: () => _onSelectedLetterTap(idx),
                                        child: Container(
                                          width: 44,
                                          height: 48,
                                          margin: const EdgeInsets.symmetric(horizontal: 3),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF538D4E)
                                                : const Color(0xFF6AAA64),
                                            borderRadius: BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 3,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(
                                            char,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),
                                  ),
                          ),

                          const SizedBox(height: 14),

                          // Control Buttons: Sil & Gönder
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Row(
                              children: [
                                OutlinedButton.icon(
                                  onPressed: _onClearWord,
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  label: const Text('Temizle'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  onPressed: _onShuffleRack,
                                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                                  label: const Text('Karıştır'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                                const Spacer(),
                                FilledButton.icon(
                                  onPressed: _onSubmitWord,
                                  icon: const Icon(Icons.check_rounded, size: 20),
                                  label: const Text('Gönder'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: isDark
                                        ? const Color(0xFF538D4E)
                                        : const Color(0xFF6AAA64),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 18),

                          // The Letter Rack (7 letters)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(_rackLetters.length, (index) {
                                final char = _rackLetters[index];
                                final isUsed = _selectedRackIndices.contains(index);

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.5),
                                    child: GestureDetector(
                                      onTap: () => _onRackLetterTap(index),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        height: 56,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: isUsed
                                              ? (isDark ? const Color(0xFF2C323B) : const Color(0xFFE2E6EA))
                                              : (isDark ? const Color(0xFF3B4350) : const Color(0xFFD4DAE2)),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isUsed
                                                ? Colors.transparent
                                                : (isDark ? const Color(0xFF566270) : const Color(0xFFBAC3CF)),
                                            width: 1.5,
                                          ),
                                          boxShadow: isUsed
                                              ? []
                                              : [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                        ),
                                        child: Text(
                                          char,
                                          style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: isUsed
                                                ? (isDark ? const Color(0xFF566270) : const Color(0xFFA0AEC0))
                                                : (isDark ? Colors.white : const Color(0xFF1A1A1B)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),

                          const SizedBox(height: 18),
                          const Divider(height: 1),

                          // Found Words Section Header
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: Row(
                              children: [
                                Text(
                                  'Bulunan Kelimeler (${_foundWords.length})',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'Anlam için kelimeye dokunun',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Found Words Chips List
                          Expanded(
                            child: _foundWords.isEmpty
                                ? Center(
                                    child: Text(
                                      'Henüz kelime bulunmadı.\nYukarıdaki harflerden 3 veya daha fazla harf seçin.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                                      ),
                                    ),
                                  )
                                : SingleChildScrollView(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _foundWords.entries.map((entry) {
                                        return ActionChip(
                                          avatar: CircleAvatar(
                                            backgroundColor: const Color(0xFF6AAA64),
                                            radius: 10,
                                            child: Text(
                                              '${entry.key.length}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          label: Text(
                                            entry.key,
                                            style: const TextStyle(fontWeight: FontWeight.w700),
                                          ),
                                          onPressed: () => _showWordMeaningDialog(entry.key, entry.value),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                          ),
                        ],
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
