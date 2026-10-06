import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/crossword_model.dart';
import '../models/letter_state.dart';
import '../services/crossword_service.dart';
import '../theme/app_theme.dart';
import '../widgets/virtual_keyboard.dart';

class CengelBulmacaScreen extends StatefulWidget {
  const CengelBulmacaScreen({super.key});

  @override
  State<CengelBulmacaScreen> createState() => _CengelBulmacaScreenState();
}

class _CengelBulmacaScreenState extends State<CengelBulmacaScreen>
    with SingleTickerProviderStateMixin {
  final CrosswordService _crosswordService = CrosswordService();

  CrosswordPuzzle? _puzzle;
  bool _isLoading = true;
  String? _errorMessage;

  // Izgara hücreleri: "row,col" -> CrosswordCell
  final Map<String, CrosswordCell> _cells = {};

  // Aktif seçili ipucu ve hücre koordinatı
  CrosswordClue? _activeClue;
  int _activeRow = 0;
  int _activeCol = 0;

  // İstatistikler
  int _hintsUsed = 0;
  String? _toastMessage;

  // Klavye harf durumları
  final Map<String, LetterStatus> _keyboardStatuses = {};

  // Kamera ve Odaklanma Kontrolleri
  late final TransformationController _transformationController;
  late final AnimationController _focusAnimController;
  Animation<Matrix4>? _focusAnimation;
  Size? _viewportSize;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        if (_focusAnimation != null) {
          _transformationController.value = _focusAnimation!.value;
        }
      });
    _loadPuzzle();
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _loadPuzzle([String? excludeId]) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _toastMessage = null;
      _cells.clear();
      _keyboardStatuses.clear();
    });

    try {
      final puzzle = await _crosswordService.getRandomPuzzle(excludeId);

      // Izgara hücrelerini oluştur ve başlangıç numaralarını ata
      final Map<String, CrosswordCell> newCells = {};

      for (final clue in puzzle.clues) {
        for (int i = 0; i < clue.length; i++) {
          final r = clue.getRowForIndex(i);
          final c = clue.getColForIndex(i);
          final key = '$r,$c';
          final char = clue.word[i];

          if (!newCells.containsKey(key)) {
            newCells[key] = CrosswordCell(
              row: r,
              col: c,
              correctChar: char,
              clueNumber: (i == 0) ? clue.id : null,
              clueIds: [clue.id],
            );
          } else {
            // Kesişen hücre: birden fazla ipucu geçer
            final existing = newCells[key]!;
            if (!existing.clueIds.contains(clue.id)) {
              existing.clueIds.add(clue.id);
            }
            if (i == 0 && existing.clueNumber == null) {
              existing.clueNumber = clue.id;
            }
          }
        }
      }

      final firstClue = puzzle.clues.first;

      setState(() {
        _puzzle = puzzle;
        _cells.addAll(newCells);
        _activeClue = firstClue;
        _activeRow = firstClue.startRow;
        _activeCol = firstClue.startCol;
        _isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _activeClue != null) {
          _focusOnClue(_activeClue!, animate: false);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Bulmaca yüklenirken bir sorun oluştu: $e';
      });
    }
  }

  void _showToast(String message) {
    setState(() {
      _toastMessage = message;
    });

    Future.delayed(const Duration(milliseconds: 2300), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  /// Aktif hücreye harf yazma
  void _onKeyPressed(String char) {
    if (_puzzle == null || _activeClue == null) return;

    final key = '$_activeRow,$_activeCol';
    final cell = _cells[key];
    if (cell == null) return;

    if (cell.isRevealedByHint) {
      _moveCursor(forward: true);
      return;
    }

    final clue = _activeClue!;
    final wasSolvedBefore = _isClueSolved(clue);

    HapticFeedback.lightImpact();

    setState(() {
      cell.enteredChar = char.toUpperCase();
    });

    final isNowSolved = _isClueSolved(clue);

    if (!wasSolvedBefore && isNowSolved) {
      _checkActiveClueCompletion();
    } else {
      // Otomatik olarak sıradaki hücreye geç
      _moveCursor(forward: true);
    }
  }

  /// SİL (Backspace)
  void _onDeletePressed() {
    if (_puzzle == null || _activeClue == null) return;

    final key = '$_activeRow,$_activeCol';
    final cell = _cells[key];
    if (cell == null) return;

    HapticFeedback.lightImpact();

    if (cell.enteredChar.isNotEmpty && !cell.isRevealedByHint) {
      setState(() {
        cell.enteredChar = '';
      });
    } else {
      // Önceki hücreye git ve sil
      _moveCursor(forward: false);
      final prevKey = '$_activeRow,$_activeCol';
      final prevCell = _cells[prevKey];
      if (prevCell != null && !prevCell.isRevealedByHint) {
        setState(() {
          prevCell.enteredChar = '';
        });
      }
    }
  }

  /// GİRİŞ (Enter) - Sıradaki çözülmemiş ipucuna atla
  void _onEnterPressed() {
    if (_puzzle == null) return;
    _selectNextUnsolvedClue();
  }

  /// İPUCU (HARF AÇ) ÖZELLİĞİ:
  /// Kullanıcının üzerinde çalıştığı kelimedeki bir harfin yerini ve kendisini gösterir.
  void _useHint() {
    if (_puzzle == null || _activeClue == null) return;

    final clue = _activeClue!;

    // 1. Önce aktif hücre boş ya da hatalıysa doğrudan orayı aç
    final activeKey = '$_activeRow,$_activeCol';
    final activeCell = _cells[activeKey];

    CrosswordCell? targetCell;
    int targetSlotIndex = 0;

    if (activeCell != null && (!activeCell.isCorrect || !activeCell.isRevealedByHint)) {
      targetCell = activeCell;
      for (int i = 0; i < clue.length; i++) {
        if (clue.getRowForIndex(i) == _activeRow && clue.getColForIndex(i) == _activeCol) {
          targetSlotIndex = i;
          break;
        }
      }
    } else {
      // 2. Aktif hücre zaten doğruysa, kelimedeki ilk açılmamış / hatalı harfi bul
      for (int i = 0; i < clue.length; i++) {
        final r = clue.getRowForIndex(i);
        final c = clue.getColForIndex(i);
        final cCell = _cells['$r,$c'];
        if (cCell != null && (!cCell.isCorrect || !cCell.isRevealedByHint)) {
          targetCell = cCell;
          targetSlotIndex = i;
          break;
        }
      }
    }

    if (targetCell == null) {
      _showToast('Bu kelimenin tüm harfleri zaten doğru!');
      return;
    }

    final wasSolvedBefore = _isClueSolved(clue);

    HapticFeedback.mediumImpact();

    setState(() {
      _hintsUsed++;
      targetCell!.enteredChar = targetCell.correctChar;
      targetCell.isRevealedByHint = true;
      _activeRow = targetCell.row;
      _activeCol = targetCell.col;
    });

    final revealedLetter = targetCell.correctChar;
    final slotNumber = targetSlotIndex + 1;
    _showToast('İpucu: "$revealedLetter" harfi $slotNumber. kutuya yerleştirildi');

    final isNowSolved = _isClueSolved(clue);
    if (!wasSolvedBefore && isNowSolved) {
      _checkActiveClueCompletion();
    } else {
      // İpucundan sonra sıradaki boş hücreye odaklan
      _moveCursor(forward: true);
    }
  }

  /// Kürsörü aktif kelime doğrultusunda ileri/geri taşır
  void _moveCursor({required bool forward}) {
    if (_activeClue == null) return;
    final clue = _activeClue!;

    int currentIndex = -1;
    for (int i = 0; i < clue.length; i++) {
      if (clue.getRowForIndex(i) == _activeRow && clue.getColForIndex(i) == _activeCol) {
        currentIndex = i;
        break;
      }
    }

    if (currentIndex == -1) return;

    final nextIndex = forward ? currentIndex + 1 : currentIndex - 1;
    if (nextIndex >= 0 && nextIndex < clue.length) {
      setState(() {
        _activeRow = clue.getRowForIndex(nextIndex);
        _activeCol = clue.getColForIndex(nextIndex);
      });
    }
  }

  /// Aktif kelimenin tamamlanıp tamamlanmadığını kontrol eder ve sonrakine geçer
  void _checkActiveClueCompletion() {
    if (_puzzle == null || _activeClue == null) return;

    final clue = _activeClue!;
    if (!_isClueSolved(clue)) return;

    HapticFeedback.mediumImpact();

    // Tüm bulmaca çözüldü mü?
    final allSolved = _puzzle!.clues.every(_isClueSolved);
    if (allSolved) {
      HapticFeedback.heavyImpact();
      _showVictoryDialog();
      return;
    }

    // Kelime doğru tamamlandı: Bildir ve o anki kelimeden SONRA gelen kelimeye yumuşakça odaklan
    _showToast('Tebrikler! "${clue.word}" doğru tamamlandı');
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) {
        _selectNextUnsolvedClue();
      }
    });
  }

  bool _isClueSolved(CrosswordClue clue) {
    for (int i = 0; i < clue.length; i++) {
      final r = clue.getRowForIndex(i);
      final c = clue.getColForIndex(i);
      final cell = _cells['$r,$c'];
      if (cell == null || !cell.isCorrect) {
        return false;
      }
    }
    return true;
  }

  int get _solvedCluesCount {
    if (_puzzle == null) return 0;
    return _puzzle!.clues.where(_isClueSolved).length;
  }

  /// Doğru bilindiğinde ilk kelimeye dönmek yerine,
  /// o anki kelimeden SONRA gelen ilk çözülmemiş kelimeye geçer.
  void _selectNextUnsolvedClue() {
    if (_puzzle == null) return;
    final allClues = _puzzle!.clues;
    if (allClues.isEmpty) return;

    final currentOrderIdx = _activeClue != null ? allClues.indexOf(_activeClue!) : -1;

    // Aktif kelimeden başlayarak sırayla sonraki çözülmemiş kelimeyi döngüsel olarak bul
    for (int offset = 1; offset <= allClues.length; offset++) {
      final candidate = allClues[(currentOrderIdx + offset) % allClues.length];
      if (!_isClueSolved(candidate)) {
        _selectClue(candidate);
        return;
      }
    }
  }

  /// Kelimeyi seçer ve kamerayı bu kelimeye odaklar
  void _selectClue(CrosswordClue clue, {bool animateFocus = true}) {
    HapticFeedback.selectionClick();
    setState(() {
      _activeClue = clue;
      _activeRow = clue.startRow;
      _activeCol = clue.startCol;
    });
    _focusOnClue(clue, animate: animateFocus);
  }

  /// Kamerayı belirtilen kelimeye merkezleyip odaklanma animasyonu yapar
  void _focusOnClue(CrosswordClue clue, {bool animate = true}) {
    if (_viewportSize == null || _viewportSize!.width == 0 || _viewportSize!.height == 0) {
      return;
    }

    final double centerRow = clue.direction == CrosswordDirection.across
        ? clue.startRow.toDouble()
        : clue.startRow + (clue.length - 1) / 2.0;
    final double centerCol = clue.direction == CrosswordDirection.across
        ? clue.startCol + (clue.length - 1) / 2.0
        : clue.startCol.toDouble();

    // Izgara içi padding: horizontal 24, vertical 12. Hücre: 38 px + 2 px margin = 40 px.
    final double contentX = 24.0 + centerCol * 40.0 + 20.0;
    final double contentY = 12.0 + centerRow * 40.0 + 20.0;

    final currentMatrix = _transformationController.value;
    final currentScale = currentMatrix.getMaxScaleOnAxis();
    final targetScale = currentScale < 0.65 ? 0.95 : currentScale.clamp(0.75, 1.35);

    final double tx = (_viewportSize!.width / 2.0) - (contentX * targetScale);
    final double ty = (_viewportSize!.height / 2.0) - (contentY * targetScale);

    final targetMatrix = Matrix4.identity()
      ..translateByDouble(tx, ty, 0.0, 1.0)
      ..scaleByDouble(targetScale, targetScale, 1.0, 1.0);

    if (!animate) {
      _transformationController.value = targetMatrix;
      return;
    }

    _focusAnimController.stop();
    _focusAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(
      parent: _focusAnimController,
      curve: Curves.easeInOutCubic,
    ));

    _focusAnimController.forward(from: 0.0);
  }

  void _onCellTapped(int row, int col) {
    final key = '$row,$col';
    final cell = _cells[key];
    if (cell == null) return;

    HapticFeedback.selectionClick();

    CrosswordClue? targetClue;

    setState(() {
      // Eğer tıklanan hücre zaten aktif hücre ise yönü değiştir (Across <-> Down)
      if (_activeRow == row && _activeCol == col && cell.clueIds.length > 1) {
        final otherClueId = cell.clueIds.firstWhere(
          (id) => id != _activeClue?.id,
          orElse: () => cell.clueIds.first,
        );
        _activeClue = _puzzle?.clues.firstWhere((c) => c.id == otherClueId);
      } else {
        // Tıklanan hücre aktif ipucuna ait değilse, bu hücreyi içeren ilk ipucunu seç
        if (_activeClue == null || !_isCellInClue(row, col, _activeClue!)) {
          final firstClueId = cell.clueIds.first;
          _activeClue = _puzzle?.clues.firstWhere((c) => c.id == firstClueId);
        }
      }

      _activeRow = row;
      _activeCol = col;
      targetClue = _activeClue;
    });

    if (targetClue != null) {
      _focusOnClue(targetClue!, animate: true);
    }
  }

  bool _isCellInClue(int row, int col, CrosswordClue clue) {
    for (int i = 0; i < clue.length; i++) {
      if (clue.getRowForIndex(i) == row && clue.getColForIndex(i) == col) {
        return true;
      }
    }
    return false;
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? GameColors.darkSurface : Colors.white,
          title: Column(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                size: 56,
                color: Color(0xFFD4AF37),
              ),
              const SizedBox(height: 12),
              Text(
                'Tebrikler!',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: isDark ? Colors.white : const Color(0xFF1A1A1B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '"${_puzzle?.title}" bulmacasını başarıyla tamamladınız!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white70 : const Color(0xFF4A5568),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF263238) : const Color(0xFFEDF7ED),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          'Kelimeler',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_puzzle?.clues.length ?? 0}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF438A4A),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Text(
                          'İpuçları',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_hintsUsed',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC9B458),
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
                Navigator.pop(context);
                Navigator.pop(context); // Hub'a dön
              },
              child: const Text('Menüye Dön'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _loadPuzzle(_puzzle?.id);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF438A4A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Sonraki Bulmaca'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Çengel Bulmaca',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            if (_puzzle != null)
              Text(
                '${_puzzle!.title} • $_solvedCluesCount/${_puzzle!.clues.length} Çözüldü',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
          ],
        ),
        actions: [
          // İpucu Butonu (Harf Aç - Kompakt ve taşmayan)
          IconButton(
            icon: const Icon(Icons.lightbulb_rounded, color: Color(0xFFD4AF37)),
            tooltip: 'Harf Aç',
            onPressed: _useHint,
          ),

          // Yeni Bulmaca Butonu
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yeni Bulmaca',
            onPressed: () => _loadPuzzle(_puzzle?.id),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => _loadPuzzle(),
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
                          const SizedBox(height: 4),

                          // Aktif İpucu Kartı (Soru ve Tanım)
                          _buildActiveClueCard(isDark),

                          // Bulmaca Izgarası (InteractiveViewer ile 2D serbest gezinme ve yakınlaştırma)
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
                                return InteractiveViewer(
                                  transformationController: _transformationController,
                                  boundaryMargin: const EdgeInsets.symmetric(horizontal: 240.0, vertical: 200.0),
                                  minScale: 0.35,
                                  maxScale: 2.5,
                                  constrained: false,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                                    child: _buildGrid(isDark),
                                  ),
                                );
                              },
                            ),
                          ),

                          // Ekranın Altında İri & Ergonomik Klavye
                          VirtualKeyboard(
                            letterStatuses: _keyboardStatuses,
                            onKeyPressed: _onKeyPressed,
                            onEnterPressed: _onEnterPressed,
                            onDeletePressed: _onDeletePressed,
                            showActionBar: true,
                          ),
                        ],
                      ),

                      // Bildirim / İpucu Toast Mesajı
                      if (_toastMessage != null)
                        Positioned(
                          top: 12,
                          left: 20,
                          right: 20,
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: _toastMessage != null ? 1.0 : 0.0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF2C3539) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.lightbulb_rounded, color: Color(0xFFFFD54F), size: 18),
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

  /// Aktif Soru / İpucu Kartı
  Widget _buildActiveClueCard(bool isDark) {
    if (_activeClue == null) return const SizedBox.shrink();

    final clue = _activeClue!;
    final isAcross = clue.direction == CrosswordDirection.across;
    final isSolved = _isClueSolved(clue);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? GameColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSolved
              ? const Color(0xFF438A4A).withValues(alpha: 0.6)
              : (isDark ? GameColors.darkBorder : GameColors.lightBorder),
          width: isSolved ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Yön ve Numara Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSolved
                      ? const Color(0xFF438A4A)
                      : (isDark ? const Color(0xFF374151) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isAcross ? Icons.arrow_forward_rounded : Icons.arrow_downward_rounded,
                      size: 14,
                      color: isSolved ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${clue.id}. ${isAcross ? 'Soldan Sağa' : 'Yukarıdan Aşağı'} (${clue.length} Harf)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSolved ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Önceki / Sonraki İpucu Butonları
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_left_rounded, size: 22),
                onPressed: () => _cycleClue(forward: false),
                tooltip: 'Önceki İpucu',
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                icon: const Icon(Icons.chevron_right_rounded, size: 22),
                onPressed: () => _cycleClue(forward: true),
                tooltip: 'Sonraki İpucu',
              ),
            ],
          ),
          const SizedBox(height: 6),

          // TDK Anlamı / İpucu Metni
          Text(
            clue.clue,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF2D3748),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _cycleClue({required bool forward}) {
    if (_puzzle == null || _activeClue == null) return;
    final clues = _puzzle!.clues;
    final currentIndex = clues.indexOf(_activeClue!);
    final nextIndex = forward
        ? (currentIndex + 1) % clues.length
        : (currentIndex - 1 + clues.length) % clues.length;
    _selectClue(clues[nextIndex]);
  }

  /// Bulmaca Izgarası (Pannable / Zoomable ve taşmayan hücre hesabı)
  Widget _buildGrid(bool isDark) {
    if (_puzzle == null) return const SizedBox.shrink();

    final rows = _puzzle!.rows;
    final cols = _puzzle!.cols;
    const double cellSize = 38.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(rows, (r) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(cols, (c) {
            final key = '$r,$c';
            final cell = _cells[key];

            if (cell == null) {
              // Boş kutuları gösterme (Kullanıcı isteği: Şeffaf görünmez alan)
              return SizedBox(
                width: cellSize + 2.0,
                height: cellSize + 2.0,
              );
            }

            // Çengel Bulmaca Harf Hücresi
            final isCursorHere = (r == _activeRow && c == _activeCol);
            final isInActiveClue = _activeClue != null && _isCellInClue(r, c, _activeClue!);
            final isCorrect = cell.isCorrect;
            final isRevealed = cell.isRevealedByHint;

            Color bgColor;
            Color borderColor;
            double borderWidth = 1.0;

            if (isCursorHere) {
              bgColor = isDark ? const Color(0xFF2D3748) : const Color(0xFFFEF3C7);
              borderColor = const Color(0xFFD97706);
              borderWidth = 2.4;
            } else if (isInActiveClue) {
              bgColor = isDark ? const Color(0xFF263238) : const Color(0xFFF1F5F9);
              borderColor = isDark ? const Color(0xFF4A5568) : const Color(0xFF94A3B8);
              borderWidth = 1.6;
            } else if (isCorrect) {
              bgColor = isDark ? const Color(0xFF1E3A24) : const Color(0xFFF0FDF4);
              borderColor = const Color(0xFF438A4A).withValues(alpha: 0.6);
            } else {
              bgColor = isDark ? GameColors.darkSurface : Colors.white;
              borderColor = isDark ? GameColors.darkBorder : GameColors.lightBorder;
            }

            return GestureDetector(
              onTap: () => _onCellTapped(r, c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: cellSize,
                height: cellSize,
                margin: const EdgeInsets.all(1.0),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor, width: borderWidth),
                  boxShadow: [
                    if (isCursorHere)
                      BoxShadow(
                        color: const Color(0xFFD97706).withValues(alpha: 0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Sol üst köşe ipucu numarası (varsa)
                    if (cell.clueNumber != null)
                      Positioned(
                        top: 2,
                        left: 3,
                        child: Text(
                          '${cell.clueNumber}',
                          style: TextStyle(
                            fontSize: cellSize * 0.24,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            height: 1.0,
                          ),
                        ),
                      ),

                    // İpucu ile açılmışsa sağ üstte küçük yıldız işareti
                    if (isRevealed)
                      Positioned(
                        top: 2,
                        right: 3,
                        child: Icon(
                          Icons.star_rounded,
                          size: cellSize * 0.24,
                          color: const Color(0xFFD4AF37),
                        ),
                      ),

                    // Harf Metni
                    Center(
                      child: Text(
                        cell.enteredChar,
                        style: TextStyle(
                          fontSize: cellSize * 0.52,
                          fontWeight: FontWeight.w900,
                          color: isRevealed
                              ? (isDark ? const Color(0xFFFFD54F) : const Color(0xFFB78103))
                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}
