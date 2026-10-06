import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/word_search_service.dart';
import '../theme/app_theme.dart';

class WordSearchScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const WordSearchScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  final WordSearchService _searchService = WordSearchService();

  WordSearchPuzzle? _puzzle;
  bool _isLoading = true;
  String? _toastMessage;

  // Aktif seçim yolu
  GridPoint? _selectionStart;
  List<GridPoint> _currentPath = [];

  // İpucu ile parlayan hücre
  GridPoint? _hintPoint;
  Timer? _hintTimer;

  // Zamanlayıcı
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isVictory = false;

  // Bulunan kelimeler için renk paleti (12 renk)
  static const List<Color> _wordColors = [
    Color(0xFF10B981), // Zümrüt
    Color(0xFF3B82F6), // Mavi
    Color(0xFFEC4899), // Pembe
    Color(0xFFF59E0B), // Kehribar
    Color(0xFF8B5CF6), // Mor
    Color(0xFF06B6D4), // Camgöbeği
    Color(0xFFE11D48), // Gül
    Color(0xFF84CC16), // Limon yeşili
  ];

  @override
  void initState() {
    super.initState();
    _loadPuzzle();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hintTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_isVictory) {
        setState(() {
          _secondsElapsed++;
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _loadPuzzle() async {
    setState(() {
      _isLoading = true;
      _isVictory = false;
      _selectionStart = null;
      _currentPath.clear();
      _hintPoint = null;
      _toastMessage = null;
    });

    final puzzle = await _searchService.generatePuzzle();

    setState(() {
      _puzzle = puzzle;
      _isLoading = false;
    });

    _startTimer();
  }

  void _showToast(String message) {
    setState(() {
      _toastMessage = message;
    });

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  /// Ekrandaki dokunma koordinatından (Row, Col) hücresini bulur
  GridPoint? _getGridPointFromOffset(Offset localOffset, double cellSize) {
    const margin = 8.0;
    final x = localOffset.dx - margin;
    final y = localOffset.dy - margin;

    if (x < 0 || y < 0) return null;

    final col = (x / cellSize).floor();
    final row = (y / cellSize).floor();

    if (row >= 0 && row < WordSearchService.gridSize && col >= 0 && col < WordSearchService.gridSize) {
      return GridPoint(row, col);
    }
    return null;
  }

  /// İki nokta arasındaki düz doğrultuyu (yatay, dikey veya çapraz) hesaplar
  List<GridPoint> _calculateStraightLine(GridPoint start, GridPoint end) {
    final dRow = end.row - start.row;
    final dCol = end.col - start.col;

    final absRow = dRow.abs();
    final absCol = dCol.abs();

    int stepRow = 0;
    int stepCol = 0;
    int steps = 0;

    if (absRow == 0 && absCol == 0) {
      return [start];
    } else if (absRow == 0) {
      // Yatay
      stepRow = 0;
      stepCol = dCol > 0 ? 1 : -1;
      steps = absCol;
    } else if (absCol == 0) {
      // Dikey
      stepRow = dRow > 0 ? 1 : -1;
      stepCol = 0;
      steps = absRow;
    } else if (absRow == absCol) {
      // Tam 45 derece çapraz
      stepRow = dRow > 0 ? 1 : -1;
      stepCol = dCol > 0 ? 1 : -1;
      steps = absRow;
    } else {
      // Eğik açıdaysa en yakın ana eksene veya çapraza oturt
      if (absRow > absCol * 2) {
        stepRow = dRow > 0 ? 1 : -1;
        stepCol = 0;
        steps = absRow;
      } else if (absCol > absRow * 2) {
        stepRow = 0;
        stepCol = dCol > 0 ? 1 : -1;
        steps = absCol;
      } else {
        steps = absRow.clamp(0, absCol);
        stepRow = dRow > 0 ? 1 : -1;
        stepCol = dCol > 0 ? 1 : -1;
      }
    }

    final path = <GridPoint>[];
    for (int i = 0; i <= steps; i++) {
      final r = start.row + (i * stepRow);
      final c = start.col + (i * stepCol);
      if (r >= 0 && r < WordSearchService.gridSize && c >= 0 && c < WordSearchService.gridSize) {
        path.add(GridPoint(r, c));
      }
    }

    return path;
  }

  /// Seçilen harf yolunun bir kelimeye denk gelip gelmediğini kontrol eder
  void _validateSelection(List<GridPoint> path) {
    if (_puzzle == null || path.length < 2) {
      setState(() {
        _selectionStart = null;
        _currentPath.clear();
      });
      return;
    }

    // Seçilen harfleri birleştir
    final selectedWord = path.map((pt) => _puzzle!.grid[pt.row][pt.col]).join();
    final reversedWord = path.reversed.map((pt) => _puzzle!.grid[pt.row][pt.col]).join();

    WordSearchItem? matchedItem;

    for (final item in _puzzle!.words) {
      if (item.isFound) continue;
      if (item.word == selectedWord || item.word == reversedWord) {
        // Yolun hücreleri de eşleşiyor mu kontrol et
        if (_isPathMatch(item.path, path) || _isPathMatch(item.path, path.reversed.toList())) {
          matchedItem = item;
          break;
        }
      }
    }

    if (matchedItem != null) {
      HapticFeedback.heavyImpact();
      setState(() {
        matchedItem!.isFound = true;
        _selectionStart = null;
        _currentPath.clear();
      });

      _showToast('Harika! "${matchedItem.word}" bulundu! 🎉');
      _checkVictory();
    } else {
      HapticFeedback.lightImpact();
      setState(() {
        _selectionStart = null;
        _currentPath.clear();
      });
    }
  }

  bool _isPathMatch(List<GridPoint> p1, List<GridPoint> p2) {
    if (p1.length != p2.length) return false;
    for (int i = 0; i < p1.length; i++) {
      if (p1[i] != p2[i]) return false;
    }
    return true;
  }

  void _checkVictory() {
    if (_puzzle == null) return;
    final allFound = _puzzle!.words.every((w) => w.isFound);

    if (allFound) {
      _timer?.cancel();
      setState(() {
        _isVictory = true;
      });

      HapticFeedback.heavyImpact();
      _showVictoryDialog();
    }
  }

  void _showVictoryDialog() {
    final isDark = widget.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? GameColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.emoji_events_rounded, color: Color(0xFFEAB308), size: 28),
            SizedBox(width: 10),
            Text('Tebrikler! 🎯', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '12x12 tablodaki ${_puzzle?.words.length} gizli kelimenin tamamını başarıyla buldunuz!',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Süre', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        _formatTime(_secondsElapsed),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Kelimeler', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '${_puzzle?.words.length}/${_puzzle?.words.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context); // Hub'a dön
            },
            child: const Text('Menüye Dön'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _loadPuzzle();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yeni Bulmaca'),
          ),
        ],
      ),
    );
  }

  /// İpucu Özelliği: Henüz bulunmamış ilk kelimenin başlangıç harfini parlatır
  void _onHint() {
    if (_puzzle == null || _isVictory) return;

    final unfound = _puzzle!.words.where((w) => !w.isFound).toList();
    if (unfound.isEmpty) return;

    final targetWord = unfound.first;
    final firstPoint = targetWord.path.first;

    HapticFeedback.mediumImpact();

    setState(() {
      _hintPoint = firstPoint;
    });

    _showToast('İpucu: "${targetWord.word}" kelimesinin ilk harfi parlatıldı');

    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        setState(() {
          _hintPoint = null;
        });
      }
    });
  }

  /// Kelime TDK Anlamı Dialogu
  void _showWordMeaning(WordSearchItem item) {
    final isDark = widget.isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? GameColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _wordColors[item.colorIndex].withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.menu_book_rounded, color: _wordColors[item.colorIndex], size: 22),
            ),
            const SizedBox(width: 10),
            Text(item.word, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          item.meaning.isNotEmpty ? item.meaning : 'Bu kelime için ek tanım bulunamadı.',
          style: TextStyle(
            fontSize: 14.5,
            height: 1.4,
            color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF334155),
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

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final foundCount = _puzzle?.words.where((w) => w.isFound).length ?? 0;
    final totalCount = _puzzle?.words.length ?? 0;

    return Scaffold(
      backgroundColor: isDark ? GameColors.darkBackground : GameColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Sözcük Avı (12x12)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            Text(
              'Bulunan: $foundCount / $totalCount • ${_formatTime(_secondsElapsed)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B)),
            tooltip: 'İpucu',
            onPressed: _onHint,
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: 'Temayı Değiştir',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yeni Bulmaca',
            onPressed: _loadPuzzle,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF10B981)),
                    SizedBox(height: 14),
                    Text('12x12 Sözcük Matrisi Oluşturuluyor...'),
                  ],
                ),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 4),

                      // 12x12 İnteraktif Harf Tablosu
                      Expanded(
                        flex: 6,
                        child: Center(
                          child: _buildGridArea(isDark),
                        ),
                      ),

                      // Kelime Listesi ve Durum Paneli
                      Expanded(
                        flex: 4,
                        child: _buildWordListSection(isDark),
                      ),
                    ],
                  ),

                  // Floating Toast Bildirimi
                  if (_toastMessage != null)
                    Positioned(
                      top: 10,
                      left: 20,
                      right: 20,
                      child: Center(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: _toastMessage != null ? 1.0 : 0.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF333B46) : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_rounded, color: Color(0xFF34D399), size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _toastMessage!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
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

  /// 12x12 Harf Matrisi
  Widget _buildGridArea(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 12.0;
        final availableHeight = constraints.maxHeight - 12.0;
        final maxSide = min(availableWidth, availableHeight > 0 ? availableHeight : availableWidth);
        final boardSize = maxSide.clamp(120.0, 420.0);
        final cellSize = (boardSize - 16.0) / WordSearchService.gridSize;

        return GestureDetector(
          onPanStart: (details) {
            final pt = _getGridPointFromOffset(details.localPosition, cellSize);
            if (pt != null) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectionStart = pt;
                _currentPath = [pt];
              });
            }
          },
          onPanUpdate: (details) {
            if (_selectionStart == null) return;
            final currentPt = _getGridPointFromOffset(details.localPosition, cellSize);
            if (currentPt != null) {
              final newPath = _calculateStraightLine(_selectionStart!, currentPt);
              if (newPath.length != _currentPath.length || newPath.last != _currentPath.last) {
                HapticFeedback.selectionClick();
                setState(() {
                  _currentPath = newPath;
                });
              }
            }
          },
          onPanEnd: (_) {
            if (_currentPath.isNotEmpty) {
              _validateSelection(_currentPath);
            }
          },
          onTapDown: (details) {
            final pt = _getGridPointFromOffset(details.localPosition, cellSize);
            if (pt == null) return;

            HapticFeedback.selectionClick();

            if (_selectionStart == null) {
              setState(() {
                _selectionStart = pt;
                _currentPath = [pt];
              });
            } else {
              // İkinci dokunuş: Düz çizgi mi kontrol et ve bitir
              final newPath = _calculateStraightLine(_selectionStart!, pt);
              _validateSelection(newPath);
            }
          },
          child: Container(
            width: boardSize,
            height: boardSize,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E232A) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? GameColors.darkBorder : GameColors.lightBorder,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: List.generate(WordSearchService.gridSize, (r) {
                return Expanded(
                  child: Row(
                    children: List.generate(WordSearchService.gridSize, (c) {
                      final pt = GridPoint(r, c);
                      final char = _puzzle?.grid[r][c] ?? '';

                      // Bu hücre aktif seçim yolunda mı?
                      final isSelected = _currentPath.contains(pt);

                      // Bu hücre daha önce bulunmuş bir kelimeye ait mi?
                      Color? foundColor;
                      if (_puzzle != null) {
                        for (final item in _puzzle!.words) {
                          if (item.isFound && item.path.contains(pt)) {
                            foundColor = _wordColors[item.colorIndex];
                            break;
                          }
                        }
                      }

                      // Bu hücre ipucuyla parlıyor mu?
                      final isHinted = (_hintPoint == pt);

                      Color bgColor = Colors.transparent;
                      Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);

                      if (isSelected) {
                        bgColor = const Color(0xFF3B82F6).withValues(alpha: 0.45);
                        textColor = Colors.white;
                      } else if (foundColor != null) {
                        bgColor = foundColor.withValues(alpha: isDark ? 0.35 : 0.25);
                        textColor = isDark ? Colors.white : foundColor;
                      } else if (isHinted) {
                        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.5);
                        textColor = Colors.white;
                      }

                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.all(1.0),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF3B82F6)
                                  : (isHinted
                                      ? const Color(0xFFF59E0B)
                                      : (foundColor != null
                                          ? foundColor.withValues(alpha: 0.7)
                                          : Colors.transparent)),
                              width: (isSelected || isHinted) ? 2.0 : 1.0,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            char,
                            style: TextStyle(
                              fontSize: cellSize * 0.48,
                              fontWeight: (foundColor != null || isSelected || isHinted)
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
        );
      },
    );
  }

  /// Bulunması Gereken Kelimeler Listesi
  Widget _buildWordListSection(bool isDark) {
    if (_puzzle == null) return const SizedBox.shrink();

    final words = _puzzle!.words;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? GameColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? GameColors.darkBorder : GameColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GİZLİ KELİMELER',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Anlam için dokunun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: words.map((item) {
                  final color = _wordColors[item.colorIndex];

                  return InkWell(
                    onTap: () => _showWordMeaning(item),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: item.isFound
                            ? color.withValues(alpha: isDark ? 0.25 : 0.15)
                            : (isDark ? const Color(0xFF333B46) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: item.isFound
                              ? color.withValues(alpha: 0.8)
                              : (isDark ? GameColors.darkBorder : GameColors.lightBorder),
                          width: item.isFound ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.isFound) ...[
                            Icon(Icons.check_rounded, size: 15, color: color),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            item.word,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              decoration: item.isFound ? TextDecoration.lineThrough : null,
                              decorationColor: color,
                              decorationThickness: 2.0,
                              color: item.isFound
                                  ? color
                                  : (isDark ? Colors.white : const Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
