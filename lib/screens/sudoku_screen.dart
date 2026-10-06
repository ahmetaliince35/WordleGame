import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/sudoku_service.dart';
import '../theme/app_theme.dart';

class _SudokuMove {
  final int row;
  final int col;
  final int prevValue;
  final int newValue;
  final Set<int> prevNotes;
  final Set<int> newNotes;

  const _SudokuMove({
    required this.row,
    required this.col,
    required this.prevValue,
    required this.newValue,
    required this.prevNotes,
    required this.newNotes,
  });
}

class SudokuScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const SudokuScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<SudokuScreen> createState() => _SudokuScreenState();
}

class _SudokuScreenState extends State<SudokuScreen> {
  final SudokuService _sudokuService = SudokuService();

  String _currentDifficulty = 'Orta';
  SudokuPuzzle? _puzzle;
  bool _isLoading = true;

  // 9x9 Kullanıcı tahtası ve notlar
  List<List<int>> _userGrid = List.generate(9, (_) => List.filled(9, 0));
  List<List<Set<int>>> _notesGrid = List.generate(9, (_) => List.generate(9, (_) => <int>{}));

  // Seçili hücre
  int _selectedRow = -1;
  int _selectedCol = -1;

  // Not modu (Aday sayılar)
  bool _isNoteMode = false;

  // Geri alma yığını
  final List<_SudokuMove> _moveHistory = [];

  // İstatistikler & Sayaç
  int _mistakes = 0;
  int _hintsUsed = 0;
  bool _isGameCompleted = false;
  String? _toastMessage;

  // Zamanlayıcı
  Timer? _timer;
  int _secondsElapsed = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame(_currentDifficulty);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _secondsElapsed = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_isGameCompleted) {
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

  void _startNewGame(String difficulty) {
    _currentDifficulty = difficulty;
    setState(() {
      _isLoading = true;
      _isGameCompleted = false;
      _mistakes = 0;
      _hintsUsed = 0;
      _selectedRow = -1;
      _selectedCol = -1;
      _moveHistory.clear();
      _isNoteMode = false;
      _toastMessage = null;
    });

    final puzzle = _sudokuService.generatePuzzle(difficulty);

    setState(() {
      _puzzle = puzzle;
      _userGrid = List.generate(9, (r) => List<int>.from(puzzle.initial[r]));
      _notesGrid = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
      _isLoading = false;
    });

    _startTimer();
  }

  void _showToast(String message) {
    setState(() {
      _toastMessage = message;
    });

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  bool _isInitialClue(int r, int c) {
    if (_puzzle == null) return false;
    return _puzzle!.initial[r][c] != 0;
  }

  void _onCellTap(int r, int c) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedRow == r && _selectedCol == c) {
        // İkinci kez basılırsa seçimi kaldır
        _selectedRow = -1;
        _selectedCol = -1;
      } else {
        _selectedRow = r;
        _selectedCol = c;
      }
    });
  }

  /// Sayı tuşuna (1-9) basıldığında
  void _onNumberInput(int num) {
    if (_selectedRow == -1 || _selectedCol == -1 || _isGameCompleted) return;
    if (_isInitialClue(_selectedRow, _selectedCol)) return;

    final r = _selectedRow;
    final c = _selectedCol;
    final currentVal = _userGrid[r][c];
    final currentNotes = Set<int>.from(_notesGrid[r][c]);

    // 1. Not Modu Açık: Hücreye not (aday sayı) ekle/kaldır
    if (_isNoteMode) {
      HapticFeedback.lightImpact();
      final newNotes = Set<int>.from(currentNotes);
      if (newNotes.contains(num)) {
        newNotes.remove(num);
      } else {
        newNotes.add(num);
      }

      final move = _SudokuMove(
        row: r,
        col: c,
        prevValue: currentVal,
        newValue: 0,
        prevNotes: currentNotes,
        newNotes: newNotes,
      );

      setState(() {
        _notesGrid[r][c] = newNotes;
        _userGrid[r][c] = 0;
        _moveHistory.add(move);
      });
      return;
    }

    // 2. Normal Mod: Hücreye sayı yaz veya aynıysa sil
    HapticFeedback.mediumImpact();
    final int nextVal = (currentVal == num) ? 0 : num;

    // Hata kontrolü
    if (nextVal != 0 && _puzzle != null && _puzzle!.solution[r][c] != nextVal) {
      HapticFeedback.vibrate();
      setState(() {
        _mistakes++;
      });
      _showToast('Hatalı sayı! Dikkatli olun.');
    }

    final move = _SudokuMove(
      row: r,
      col: c,
      prevValue: currentVal,
      newValue: nextVal,
      prevNotes: currentNotes,
      newNotes: const {},
    );

    setState(() {
      _userGrid[r][c] = nextVal;
      _notesGrid[r][c].clear();
      _moveHistory.add(move);
    });

    _checkCompletion();
  }

  /// Seçili hücreyi sil
  void _onErase() {
    if (_selectedRow == -1 || _selectedCol == -1 || _isGameCompleted) return;
    if (_isInitialClue(_selectedRow, _selectedCol)) return;

    final r = _selectedRow;
    final c = _selectedCol;
    final currentVal = _userGrid[r][c];
    final currentNotes = Set<int>.from(_notesGrid[r][c]);

    if (currentVal == 0 && currentNotes.isEmpty) return;

    HapticFeedback.lightImpact();
    final move = _SudokuMove(
      row: r,
      col: c,
      prevValue: currentVal,
      newValue: 0,
      prevNotes: currentNotes,
      newNotes: const {},
    );

    setState(() {
      _userGrid[r][c] = 0;
      _notesGrid[r][c].clear();
      _moveHistory.add(move);
    });
  }

  /// Son hamleyi geri al
  void _onUndo() {
    if (_moveHistory.isEmpty || _isGameCompleted) return;

    HapticFeedback.lightImpact();
    final lastMove = _moveHistory.removeLast();

    setState(() {
      _userGrid[lastMove.row][lastMove.col] = lastMove.prevValue;
      _notesGrid[lastMove.row][lastMove.col] = Set<int>.from(lastMove.prevNotes);
      _selectedRow = lastMove.row;
      _selectedCol = lastMove.col;
    });
  }

  /// İpucu: Seçili boş veya hatalı hücreye doğru sayıyı yerleştir
  void _onHint() {
    if (_puzzle == null || _isGameCompleted) return;

    int targetRow = _selectedRow;
    int targetCol = _selectedCol;

    // Eğer seçili hücre yoksa veya başlangıç ipucuysa ilk boş hücreyi bul
    if (targetRow == -1 || targetCol == -1 || _isInitialClue(targetRow, targetCol)) {
      bool found = false;
      for (int r = 0; r < 9; r++) {
        for (int c = 0; c < 9; c++) {
          if (_userGrid[r][c] != _puzzle!.solution[r][c]) {
            targetRow = r;
            targetCol = c;
            found = true;
            break;
          }
        }
        if (found) break;
      }
      if (!found) {
        _showToast('Tüm hücreler zaten doğru doldurulmuş!');
        return;
      }
    }

    final correctValue = _puzzle!.solution[targetRow][targetCol];

    HapticFeedback.heavyImpact();
    setState(() {
      _hintsUsed++;
      _selectedRow = targetRow;
      _selectedCol = targetCol;
      _userGrid[targetRow][targetCol] = correctValue;
      _notesGrid[targetRow][targetCol].clear();
    });

    _showToast('İpucu: $correctValue yerleştirildi');
    _checkCompletion();
  }

  /// Bulmaca tamamlandı mı kontrol et
  void _checkCompletion() {
    if (_puzzle == null) return;

    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_userGrid[r][c] != _puzzle!.solution[r][c]) {
          return;
        }
      }
    }

    // Zafer!
    _timer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _isGameCompleted = true;
    });

    _showVictoryDialog();
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
            Text('Tebrikler! 🏆', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_currentDifficulty seviyesindeki Sudoku bulmacasını başarıyla çözdünüz!',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
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
                      const Text('Hata', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '$_mistakes',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('İpucu', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Text(
                        '$_hintsUsed',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              _startNewGame(_currentDifficulty);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yeni Oyun'),
          ),
        ],
      ),
    );
  }

  /// Tahtadaki bir sayının kaç kez yerleştirildiğini sayar
  int _countNumberOnBoard(int num) {
    int count = 0;
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (_userGrid[r][c] == num) count++;
      }
    }
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? GameColors.darkBackground : GameColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'Sudoku',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: 'Temayı Değiştir',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yeniden Başlat',
            onPressed: () => _startNewGame(_currentDifficulty),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6366F1)),
              )
            : Stack(
                children: [
                  Column(
                    children: [
                      // Seviye Seçici (Kolay, Orta, Zor, Çok Zor)
                      _buildDifficultySelector(isDark),

                      // Zamanlayıcı ve Hata Bilgisi
                      _buildStatsBar(isDark),

                      const SizedBox(height: 6),

                      // 9x9 Sudoku Tablosu
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            child: _buildSudokuBoard(isDark),
                          ),
                        ),
                      ),

                      // Aksiyon Butonları (Geri Al, Sil, Not Modu, İpucu)
                      _buildControlButtons(isDark),

                      const SizedBox(height: 8),

                      // Rakam Tuş Takımı (1-9)
                      _buildNumberPad(isDark),

                      const SizedBox(height: 12),
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
                    ),
                ],
              ),
      ),
    );
  }

  /// 4 Seviyeli Zorluk Seçici
  Widget _buildDifficultySelector(bool isDark) {
    const levels = ['Kolay', 'Orta', 'Zor', 'Çok Zor'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: levels.map((lvl) {
            final isSelected = _currentDifficulty == lvl;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Text(lvl),
                selected: isSelected,
                onSelected: (val) {
                  if (val && _currentDifficulty != lvl) {
                    _startNewGame(lvl);
                  }
                },
                selectedColor: const Color(0xFF6366F1),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 11.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Süre & Hata Sayacı Barı
  Widget _buildStatsBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Text(
                _formatTime(_secondsElapsed),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Text(
                'Hata: $_mistakes',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _mistakes > 0 ? const Color(0xFFEF4444) : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 9x9 Sudoku Matrisi
  Widget _buildSudokuBoard(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - 16;
        final availableHeight = constraints.maxHeight - 16;
        final maxSide = min(availableWidth, availableHeight > 0 ? availableHeight : availableWidth);
        final boardSize = maxSide.clamp(140.0, 390.0);
        final cellSize = (boardSize - 12) / 9;

        final selectedNum = (_selectedRow != -1 && _selectedCol != -1)
            ? _userGrid[_selectedRow][_selectedCol]
            : 0;

        return Container(
          width: boardSize,
          height: boardSize,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E232A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF64748B) : const Color(0xFF1E293B),
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: List.generate(9, (r) {
              final isBlockBottom = (r % 3 == 2 && r != 8);

              return Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isBlockBottom
                            ? (isDark ? const Color(0xFF64748B) : const Color(0xFF1E293B))
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: isBlockBottom ? 2.0 : 0.75,
                      ),
                    ),
                  ),
                  child: Row(
                    children: List.generate(9, (c) {
                      final isBlockRight = (c % 3 == 2 && c != 8);

                      final isSelected = (_selectedRow == r && _selectedCol == c);
                      final isInitial = _isInitialClue(r, c);
                      final val = _userGrid[r][c];
                      final notes = _notesGrid[r][c];

                      // Vurgulamalar
                      final isSameRowOrCol = (_selectedRow == r || _selectedCol == c);
                      final isSameBlock = (_selectedRow != -1 &&
                          (_selectedRow ~/ 3 == r ~/ 3) &&
                          (_selectedCol ~/ 3 == c ~/ 3));
                      final isSameNumber = (selectedNum != 0 && val == selectedNum);
                      final isError = (val != 0 && _puzzle != null && _puzzle!.solution[r][c] != val);

                      Color cellBg;
                      if (isSelected) {
                        cellBg = const Color(0xFF6366F1).withValues(alpha: 0.35);
                      } else if (isError) {
                        cellBg = const Color(0xFFEF4444).withValues(alpha: 0.25);
                      } else if (isSameNumber) {
                        cellBg = const Color(0xFF6366F1).withValues(alpha: 0.20);
                      } else if (isSameRowOrCol || isSameBlock) {
                        cellBg = isDark
                            ? const Color(0xFF2A3441)
                            : const Color(0xFFEEF2F6);
                      } else {
                        cellBg = Colors.transparent;
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _onCellTap(r, c),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cellBg,
                              border: Border(
                                right: BorderSide(
                                  color: isBlockRight
                                      ? (isDark ? const Color(0xFF64748B) : const Color(0xFF1E293B))
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: isBlockRight ? 2.0 : 0.75,
                                ),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: (val != 0)
                                ? Text(
                                    '$val',
                                    style: TextStyle(
                                      fontSize: cellSize * 0.52,
                                      fontWeight: isInitial ? FontWeight.w900 : FontWeight.w700,
                                      color: isError
                                          ? const Color(0xFFEF4444)
                                          : (isInitial
                                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                                              : const Color(0xFF6366F1)),
                                    ),
                                  )
                                : (notes.isNotEmpty)
                                    ? _buildNotesGrid(notes, cellSize)
                                    : const SizedBox.shrink(),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// Hücre içi 3x3 not (aday sayı) ızgarası
  Widget _buildNotesGrid(Set<int> notes, double cellSize) {
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (nr) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(3, (nc) {
              final n = nr * 3 + nc + 1;
              final hasNote = notes.contains(n);
              return Text(
                hasNote ? '$n' : '',
                style: TextStyle(
                  fontSize: cellSize * 0.23,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  height: 1.0,
                ),
              );
            }),
          );
        }),
      ),
    );
  }

  /// Araç Butonları (Geri Al, Sil, Not Modu, İpucu)
  Widget _buildControlButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          // Geri Al
          Expanded(
            child: _buildActionButton(
              icon: Icons.undo_rounded,
              label: 'Geri Al',
              onTap: _moveHistory.isNotEmpty ? _onUndo : null,
              isDark: isDark,
            ),
          ),

          // Sil
          Expanded(
            child: _buildActionButton(
              icon: Icons.backspace_outlined,
              label: 'Sil',
              onTap: _onErase,
              isDark: isDark,
            ),
          ),

          // Not Modu (Pencil)
          Expanded(
            child: _buildActionButton(
              icon: _isNoteMode ? Icons.edit_rounded : Icons.edit_outlined,
              label: _isNoteMode ? 'Not: Açık' : 'Not: Kapalı',
              isActive: _isNoteMode,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _isNoteMode = !_isNoteMode;
                });
              },
              isDark: isDark,
            ),
          ),

          // İpucu
          Expanded(
            child: _buildActionButton(
              icon: Icons.lightbulb_rounded,
              label: 'İpucu',
              iconColor: const Color(0xFFF59E0B),
              onTap: _onHint,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isDark,
    bool isActive = false,
    Color? iconColor,
  }) {
    final effectiveColor = isActive
        ? const Color(0xFF6366F1)
        : (onTap == null
            ? Colors.grey.withValues(alpha: 0.4)
            : (isDark ? Colors.white70 : const Color(0xFF475569)));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF6366F1).withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 21, color: iconColor ?? effectiveColor),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: effectiveColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 1'den 9'a Rakam Tuş Takımı
  Widget _buildNumberPad(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(9, (idx) {
          final num = idx + 1;
          final count = _countNumberOnBoard(num);
          final isCompleted = count >= 9;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Material(
                color: isCompleted
                    ? (isDark ? const Color(0xFF262E38) : const Color(0xFFE2E8F0))
                    : (isDark ? const Color(0xFF333D4B) : Colors.white),
                borderRadius: BorderRadius.circular(10),
                elevation: isCompleted ? 0 : 1.5,
                child: InkWell(
                  onTap: isCompleted ? null : () => _onNumberInput(num),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$num',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: isCompleted
                                  ? Colors.grey.withValues(alpha: 0.5)
                                  : (isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                          Text(
                            isCompleted ? '✓' : '${9 - count}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: isCompleted
                                  ? const Color(0xFF10B981)
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
