import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/game_stats.dart';
import '../models/letter_state.dart';
import '../services/database_service.dart';
import '../services/stats_service.dart';
import '../theme/app_theme.dart';
import '../utils/turkish_helper.dart';
import '../widgets/game_over_dialog.dart';
import '../widgets/help_dialog.dart';
import '../widgets/length_selector.dart';
import '../widgets/stats_dialog.dart';
import '../widgets/virtual_keyboard.dart';
import '../widgets/word_grid.dart';

class WordleScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const WordleScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<WordleScreen> createState() => _WordleScreenState();
}

class _WordleScreenState extends State<WordleScreen> {
  final FocusNode _focusNode = FocusNode();

  int _wordLength = 5;
  WordData? _currentTargetWord;
  int _currentAttempt = 0;
  String _currentInput = '';
  late List<List<TileData>> _grid;
  final Map<String, LetterStatus> _keyboardStatuses = {};

  bool _isLoading = true;
  bool _isEvaluating = false;
  bool _isGameOver = false;
  bool _isWon = false;
  bool _shakeActiveRow = false;
  String? _toastMessage;
  String? _errorMessage;

  GameStats _stats = const GameStats();

  @override
  void initState() {
    super.initState();
    // 1. Ekran ilk açıldığında UI'ın hazır olması için grid'i hemen hafızada oluştur
    _initGrid(_wordLength);

    // 2. İlk frame ekrana basıldıktan HEMEN SONRA ağır SQLite işlemlerini başlat
    // (Böylece donanım yüzeyi siyah ekranda asılı kalmaz)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNewGame(_wordLength);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _initGrid(int length) {
    _grid = List.generate(
      6,
          (_) => List.generate(length, (_) => const TileData()),
    );
  }

  Future<void> _startNewGame(int length) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _wordLength = length;
      _currentAttempt = 0;
      _currentInput = '';
      _isGameOver = false;
      _isWon = false;
      _shakeActiveRow = false;
      _toastMessage = null;
      _keyboardStatuses.clear();
      _initGrid(length);
    });

    try {
      final dbService = DatabaseService();
      await dbService.initialize();
      final wordData = await dbService.getRandomWord(length);
      final stats = await StatsService().getStatsForLength(length);

      if (mounted) {
        setState(() {
          _currentTargetWord = wordData;
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
        _showToast('Kelime yüklenirken bir sorun oluştu');
      }
    }
  }

  void _onKeyPressed(String char) {
    if (_isLoading || _isGameOver || _isEvaluating) return;
    if (_currentInput.length >= _wordLength) return;

    final upperChar = TurkishHelper.toTurkishUpper(char);
    if (!TurkishHelper.validAlphabet.contains(upperChar)) return;

    setState(() {
      final colIndex = _currentInput.length;
      _currentInput += upperChar;
      _grid[_currentAttempt][colIndex] = TileData(
        char: upperChar,
        status: LetterStatus.pending,
      );
    });
  }

  void _onDeletePressed() {
    if (_isLoading || _isGameOver || _isEvaluating) return;
    if (_currentInput.isEmpty) return;

    setState(() {
      final colIndex = _currentInput.length - 1;
      _currentInput = _currentInput.substring(0, colIndex);
      _grid[_currentAttempt][colIndex] = const TileData();
    });
  }

  Future<void> _onEnterPressed() async {
    if (_isLoading || _isGameOver || _isEvaluating) return;

    if (_currentInput.length < _wordLength) {
      _triggerShake('Lütfen $_wordLength harf tamamlayın');
      return;
    }

    final guess = _currentInput;
    final dbService = DatabaseService();
    final isValid = await dbService.isValidWord(guess, _wordLength);

    if (!isValid) {
      _triggerShake('Kelime sözlükte bulunamadı');
      setState(() {
        _currentInput = '';
        for (int i = 0; i < _wordLength; i++) {
          _grid[_currentAttempt][i] = const TileData();
        }
      });
      return;
    }

    setState(() {
      _isEvaluating = true;
    });

    final target = _currentTargetWord!.word;
    final evaluations = _evaluateGuess(guess, target);

    for (int i = 0; i < _wordLength; i++) {
      _grid[_currentAttempt][i] = TileData(
        char: guess[i],
        status: evaluations[i],
      );
    }

    final totalRevealMs = (_wordLength * 140) + 350;

    Future.delayed(Duration(milliseconds: totalRevealMs), () async {
      if (!mounted) return;

      setState(() {
        for (int i = 0; i < _wordLength; i++) {
          final char = guess[i];
          final evalStatus = evaluations[i];
          final currentStatus = _keyboardStatuses[char] ?? LetterStatus.empty;

          if (evalStatus == LetterStatus.correct) {
            _keyboardStatuses[char] = LetterStatus.correct;
          } else if (evalStatus == LetterStatus.present &&
              currentStatus != LetterStatus.correct) {
            _keyboardStatuses[char] = LetterStatus.present;
          } else if (evalStatus == LetterStatus.absent &&
              currentStatus == LetterStatus.empty) {
            _keyboardStatuses[char] = LetterStatus.absent;
          }
        }
      });

      final isWin = guess == target;

      if (isWin) {
        final updatedStats = await StatsService().recordGameResult(
          length: _wordLength,
          isWin: true,
          attemptsUsed: _currentAttempt + 1,
        );

        if (!mounted) return;
        setState(() {
          _isWon = true;
          _isGameOver = true;
          _isEvaluating = false;
          _stats = updatedStats;
        });

        _showGameOverModal(isWin: true);
      } else if (_currentAttempt >= 5) {
        final updatedStats = await StatsService().recordGameResult(
          length: _wordLength,
          isWin: false,
          attemptsUsed: 6,
        );

        if (!mounted) return;
        setState(() {
          _isGameOver = true;
          _isEvaluating = false;
          _stats = updatedStats;
        });

        _showGameOverModal(isWin: false);
      } else {
        setState(() {
          _currentAttempt++;
          _currentInput = '';
          _isEvaluating = false;
        });
      }
    });
  }

  List<LetterStatus> _evaluateGuess(String guess, String target) {
    final length = target.length;
    final result = List<LetterStatus>.filled(length, LetterStatus.absent);
    final targetChars = target.split('');
    final guessChars = guess.split('');

    final remainingCounts = <String, int>{};

    for (int i = 0; i < length; i++) {
      if (guessChars[i] == targetChars[i]) {
        result[i] = LetterStatus.correct;
      } else {
        final ch = targetChars[i];
        remainingCounts[ch] = (remainingCounts[ch] ?? 0) + 1;
      }
    }

    for (int i = 0; i < length; i++) {
      if (result[i] == LetterStatus.correct) continue;

      final ch = guessChars[i];
      final count = remainingCounts[ch] ?? 0;
      if (count > 0) {
        result[i] = LetterStatus.present;
        remainingCounts[ch] = count - 1;
      } else {
        result[i] = LetterStatus.absent;
      }
    }

    return result;
  }

  void _triggerShake(String message) {
    setState(() {
      _shakeActiveRow = true;
      _toastMessage = message;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _shakeActiveRow = false;
        });
      }
    });

    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  void _showToast(String message) {
    setState(() {
      _toastMessage = message;
    });
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _toastMessage = null;
        });
      }
    });
  }

  void _showGameOverModal({required bool isWin}) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted && _currentTargetWord != null) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => GameOverDialog(
            isWin: isWin,
            wordData: _currentTargetWord!,
            attemptsUsed: _currentAttempt + 1,
            onPlayAgain: () => _startNewGame(_wordLength),
          ),
        );
      }
    });
  }

  void _showStatsModal() {
    showDialog(
      context: context,
      builder: (ctx) => StatsDialog(
        stats: _stats,
        wordLength: _wordLength,
      ),
    );
  }

  void _showHelpModal() {
    showDialog(
      context: context,
      builder: (ctx) => const HelpDialog(),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _onEnterPressed();
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _onDeletePressed();
      return KeyEventResult.handled;
    }

    final char = event.character;
    if (char != null && char.isNotEmpty) {
      final upperChar = TurkishHelper.toTurkishUpper(char);
      if (TurkishHelper.validAlphabet.contains(upperChar)) {
        _onKeyPressed(upperChar);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final isGameInProgress = _currentAttempt > 0 || _currentInput.isNotEmpty;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TÜRKÇE WORDLE'),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline_rounded, size: 22),
              tooltip: 'Nasıl Oynanır',
              onPressed: _showHelpModal,
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded, size: 24),
              tooltip: 'İstatistikler',
              onPressed: _showStatsModal,
            ),
            IconButton(
              icon: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: 22,
              ),
              tooltip: isDark ? 'Açık Tema' : 'Karanlık Tema',
              onPressed: widget.onToggleTheme,
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 23),
              tooltip: 'Yeni Kelime',
              onPressed: () => _startNewGame(_wordLength),
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
                  strokeWidth: 2.5,
                  color: isDark ? GameColors.correctDark : GameColors.correctLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Kelime hazırlanıyor...',
                  style: TextStyle(
                    color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                    fontSize: 14,
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
                  Icon(
                    Icons.error_outline_rounded,
                    size: 48,
                    color: isDark ? GameColors.presentDark : GameColors.presentLight,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kelime Yüklenemedi',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? GameColors.darkTextPrimary : GameColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? GameColors.darkTextSecondary : GameColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => _startNewGame(_wordLength),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          )
              : Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 8),

                  // Word length selector (4, 5, 6, 7 Harfli)
                  LengthSelector(
                    selectedLength: _wordLength,
                    isGameInProgress: isGameInProgress && !_isGameOver,
                    onLengthChanged: (newLength) {
                      _startNewGame(newLength);
                    },
                  ),

                  const SizedBox(height: 12),

                  // Wordle Grid
                  Expanded(
                    child: WordGrid(
                      grid: _grid,
                      currentAttempt: _currentAttempt,
                      wordLength: _wordLength,
                      shakeActiveRow: _shakeActiveRow,
                      isWon: _isWon,
                      winningRowIndex: _currentAttempt,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Virtual Keyboard
                  VirtualKeyboard(
                    letterStatuses: _keyboardStatuses,
                    onKeyPressed: _onKeyPressed,
                    onEnterPressed: _onEnterPressed,
                    onDeletePressed: _onDeletePressed,
                  ),

                  const SizedBox(height: 6),
                ],
              ),

              // Soft Toast / Feedback Banner
              if (_toastMessage != null)
                Positioned(
                  top: 54,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _toastMessage != null ? 1.0 : 0.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF333B46) : const Color(0xFF2C3539),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
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
      ),
    );
  }
}