import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/number_puzzle_service.dart';
import '../theme/app_theme.dart';

class _NumberItem {
  final String id;
  final int value;
  final bool isOriginal;

  const _NumberItem({
    required this.id,
    required this.value,
    this.isOriginal = true,
  });
}

class _HistoryStep {
  final _NumberItem first;
  final String op;
  final _NumberItem second;
  final _NumberItem result;
  final List<_NumberItem> snapshotBefore;

  const _HistoryStep({
    required this.first,
    required this.op,
    required this.second,
    required this.result,
    required this.snapshotBefore,
  });

  String get formatted => '${first.value} $op ${second.value} = ${result.value}';
}

class IslemOyunuScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  const IslemOyunuScreen({
    super.key,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  @override
  State<IslemOyunuScreen> createState() => _IslemOyunuScreenState();
}

class _IslemOyunuScreenState extends State<IslemOyunuScreen> {
  final NumberPuzzleService _puzzleService = NumberPuzzleService();

  String _currentDifficulty = 'Orta';
  NumberPuzzle? _puzzle;
  bool _isLoading = true;

  // Aktif kullanılabilir sayılar
  List<_NumberItem> _availableNumbers = [];

  // İşlem geçmişi (Geri alma desteğiyle)
  final List<_HistoryStep> _history = [];

  // Seçili durumlar
  _NumberItem? _selectedFirstNumber;
  String? _selectedOperator;

  // Oyun istatistikleri
  int _score = 0;
  int _roundCount = 1;
  bool _isSuccess = false;
  String? _toastMessage;

  // ID oluşturucu
  int _idCounter = 0;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame({String? difficulty}) {
    if (difficulty != null) {
      _currentDifficulty = difficulty;
    }

    setState(() {
      _isLoading = true;
      _isSuccess = false;
      _selectedFirstNumber = null;
      _selectedOperator = null;
      _history.clear();
      _toastMessage = null;
    });

    final puzzle = _puzzleService.generatePuzzle(difficulty: _currentDifficulty);

    setState(() {
      _puzzle = puzzle;
      _availableNumbers = puzzle.startingNumbers.map((val) {
        _idCounter++;
        return _NumberItem(
          id: 'num_$_idCounter',
          value: val,
          isOriginal: true,
        );
      }).toList();
      _isLoading = false;
    });
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

  /// Sayı kartına tıklandığında
  void _onNumberTap(_NumberItem number) {
    if (_isSuccess) return;

    HapticFeedback.selectionClick();

    // 1. Durum: Hiç sayı seçilmemiş -> İlk sayı olarak ata
    if (_selectedFirstNumber == null) {
      setState(() {
        _selectedFirstNumber = number;
      });
      return;
    }

    // 2. Durum: İlk sayı seçilmiş ama henüz işlem seçilmemiş
    if (_selectedOperator == null) {
      if (_selectedFirstNumber!.id == number.id) {
        // Aynı sayıya tekrar basılırsa seçimi kaldır
        setState(() {
          _selectedFirstNumber = null;
        });
      } else {
        // Başka bir sayıya basılırsa ilk sayıyı değiştir
        setState(() {
          _selectedFirstNumber = number;
        });
      }
      return;
    }

    // 3. Durum: İlk sayı ve işlem seçilmiş -> İkinci sayı olarak ata ve işlemi çalıştır
    if (_selectedFirstNumber!.id == number.id) {
      // Bir sayıyı kendisiyle aynı anda kullanamaz
      _showToast('Bir sayıyı kendisiyle işleme sokamazsınız!');
      return;
    }

    _executeOperation(_selectedFirstNumber!, _selectedOperator!, number);
  }

  /// İşlem operatörüne (+, -, ×, ÷) tıklandığında
  void _onOperatorTap(String op) {
    if (_isSuccess) return;

    if (_selectedFirstNumber == null) {
      _showToast('Önce bir sayı seçin!');
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _selectedOperator = op;
    });
  }

  /// 4 işlemi gerçekleştirir ve sonucu tahtaya ekler
  void _executeOperation(_NumberItem num1, String op, _NumberItem num2) {
    int? resultValue;
    String? errorReason;
    _NumberItem effectiveFirst = num1;
    _NumberItem effectiveSecond = num2;

    switch (op) {
      case '+':
        resultValue = num1.value + num2.value;
        break;

      case '-':
        if (num1.value > num2.value) {
          resultValue = num1.value - num2.value;
        } else if (num2.value > num1.value) {
          // Kullanıcı dostu: Büyükten küçüğü otomatik çıkar
          resultValue = num2.value - num1.value;
          effectiveFirst = num2;
          effectiveSecond = num1;
        } else {
          errorReason = 'Çıkarma sonucunda 0 elde edilemez (yalnızca pozitif tam sayılar).';
        }
        break;

      case '×':
        resultValue = num1.value * num2.value;
        break;

      case '÷':
        if (num2.value != 0 && num1.value % num2.value == 0) {
          resultValue = num1.value ~/ num2.value;
        } else if (num1.value != 0 && num2.value % num1.value == 0) {
          // Kullanıcı dostu: Büyük küçüğe bölünüyorsa otomatik uyarla
          resultValue = num2.value ~/ num1.value;
          effectiveFirst = num2;
          effectiveSecond = num1;
        } else {
          errorReason = 'Bölme işlemi tam bölünmeli (kalan olamaz)!';
        }
        break;
    }

    if (resultValue == null || errorReason != null) {
      HapticFeedback.vibrate();
      _showToast(errorReason ?? 'Geçersiz işlem!');
      return;
    }

    HapticFeedback.mediumImpact();

    // Önceki durumu kopyala (Geri alma için)
    final snapshotBefore = List<_NumberItem>.from(_availableNumbers);

    _idCounter++;
    final resultItem = _NumberItem(
      id: 'res_$_idCounter',
      value: resultValue,
      isOriginal: false,
    );

    final step = _HistoryStep(
      first: effectiveFirst,
      op: op,
      second: effectiveSecond,
      result: resultItem,
      snapshotBefore: snapshotBefore,
    );

    setState(() {
      _history.add(step);

      // İki sayıyı havuzdan çıkar, yeni sonucu ekle
      _availableNumbers.removeWhere(
        (item) => item.id == num1.id || item.id == num2.id,
      );
      _availableNumbers.add(resultItem);

      // Seçimleri temizle
      _selectedFirstNumber = null;
      _selectedOperator = null;
    });

    // Hedefe ulaşıldı mı kontrol et
    if (_puzzle != null && resultValue == _puzzle!.target) {
      HapticFeedback.heavyImpact();
      final earnedPts = 100 + (_history.length <= 3 ? 20 : 0);
      setState(() {
        _isSuccess = true;
        _score += earnedPts;
      });
      _showVictoryDialog(earnedPts);
    } else {
      _showToast('${step.formatted} işlemi yapıldı');
    }
  }

  /// Son işlemi geri al
  void _onUndo() {
    if (_history.isEmpty || _isSuccess) return;

    HapticFeedback.lightImpact();
    final lastStep = _history.removeLast();

    setState(() {
      _availableNumbers = List<_NumberItem>.from(lastStep.snapshotBefore);
      _selectedFirstNumber = null;
      _selectedOperator = null;
    });

    _showToast('Son işlem geri alındı');
  }

  /// Tüm işlemleri sıfırla ve başlangıç sayılarına dön
  void _onReset() {
    if (_puzzle == null || _history.isEmpty || _isSuccess) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _history.clear();
      _selectedFirstNumber = null;
      _selectedOperator = null;
      _availableNumbers = _puzzle!.startingNumbers.map((val) {
        _idCounter++;
        return _NumberItem(
          id: 'num_$_idCounter',
          value: val,
          isOriginal: true,
        );
      }).toList();
    });

    _showToast('Tüm işlemler sıfırlandı');
  }

  /// En yakın farkı hesaplar
  int get _closestDistance {
    if (_puzzle == null || _availableNumbers.isEmpty) return 9999;
    int minDiff = 99999;
    for (final item in _availableNumbers) {
      final diff = (item.value - _puzzle!.target).abs();
      if (diff < minDiff) {
        minDiff = diff;
      }
    }
    return minDiff;
  }

  int get _closestValue {
    if (_puzzle == null || _availableNumbers.isEmpty) return 0;
    int closestVal = _availableNumbers.first.value;
    int minDiff = (closestVal - _puzzle!.target).abs();

    for (final item in _availableNumbers) {
      final diff = (item.value - _puzzle!.target).abs();
      if (diff < minDiff) {
        minDiff = diff;
        closestVal = item.value;
      }
    }
    return closestVal;
  }

  /// Pes Et / Çözümü Göster
  void _showSolutionModal() {
    if (_puzzle == null) return;

    HapticFeedback.mediumImpact();
    final isDark = widget.isDarkMode;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? GameColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final steps = _puzzle!.solutionSteps;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lightbulb_rounded, color: Color(0xFF0D9488), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Hedefe Ulaşma Yolu',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Hedef: ${_puzzle!.target} (${steps.length} Adımda)',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (steps.isEmpty)
                const Text('Bu hedef için adımlar bulunamadı.')
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: steps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final s = steps[idx];
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF333B46) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? GameColors.darkBorder : GameColors.lightBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: const Color(0xFF0D9488),
                              child: Text(
                                '${idx + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              s.formatted,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startNewGame();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D9488),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Yeni Bulmaca Başlat',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mevcut sonuçla bitirme dialogu
  void _finishWithClosest() {
    if (_puzzle == null || _availableNumbers.isEmpty) return;

    final diff = _closestDistance;
    final closest = _closestValue;
    int earned = 0;

    if (diff == 0) {
      earned = 100;
    } else if (diff <= 2) {
      earned = 80;
    } else if (diff <= 5) {
      earned = 60;
    } else if (diff <= 10) {
      earned = 40;
    } else {
      earned = 20;
    }

    setState(() {
      _score += earned;
      _roundCount++;
    });

    final isDark = widget.isDarkMode;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? GameColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              diff == 0 ? Icons.check_circle_rounded : Icons.star_rounded,
              color: diff == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
            ),
            const SizedBox(width: 10),
            Text(diff == 0 ? 'Tam İsabet!' : 'Oyun Tamamlandı'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hedef Sayı: ${_puzzle!.target}'),
            const SizedBox(height: 4),
            Text('Bulunan En Yakın: $closest (Fark: $diff)'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF333B46) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+$earned Puan Kazandınız!',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showSolutionModal();
            },
            child: const Text('Çözümü Gör'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _startNewGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sonraki Soru'),
          ),
        ],
      ),
    );
  }

  /// Zafer Dialogu
  void _showVictoryDialog(int earnedPts) {
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
              'Hedef sayı olan ${_puzzle?.target} değerine ${_history.length} işlemle başarıyla ulaştınız!',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D9488).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kazanılan Puan:', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '+$earnedPts',
                    style: const TextStyle(
                      color: Color(0xFF0D9488),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
              _roundCount++;
              _startNewGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sonraki Soru'),
          ),
        ],
      ),
    );
  }

  /// Oyun Kuralları Rehberi
  void _showRulesDialog() {
    final isDark = widget.isDarkMode;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? GameColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.help_outline_rounded, color: Color(0xFF0D9488)),
            SizedBox(width: 10),
            Text('Nasıl Oynanır?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRuleItem('1', 'Size en fazla 50 değerinde sayılar ve bir hedef sayı verilir.'),
            const SizedBox(height: 8),
            _buildRuleItem('2', '4 işlem (+, -, ×, ÷) kullanarak hedef sayıya ulaşmaya çalışın.'),
            const SizedBox(height: 8),
            _buildRuleItem('3', 'Her verilen başlangıç sayısı yalnızca bir kez kullanılabilir.'),
            const SizedBox(height: 8),
            _buildRuleItem('4', 'İşlem sonucunda elde ettiğiniz yeni sayıyı sonraki işlemlerde kullanabilirsiniz.'),
            const SizedBox(height: 8),
            _buildRuleItem('5', 'Tüm işlemler pozitif tam sayı olmalı (kalanlı bölme veya negatif çıkarma yapılamaz).'),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D9488),
              foregroundColor: Colors.white,
            ),
            child: const Text('Anladım'),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String num, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: const Color(0xFF0D9488),
          child: Text(
            num,
            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.3)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? GameColors.darkBackground : GameColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bir İşlem',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              'Soru $_roundCount • Toplam: $_score Puan',
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
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Nasıl Oynanır?',
            onPressed: _showRulesDialog,
          ),
          IconButton(
            icon: Icon(isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            tooltip: 'Temayı Değiştir',
            onPressed: widget.onToggleTheme,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Yeni Soru',
            onPressed: () => _startNewGame(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF0D9488)),
              )
            : Stack(
                children: [
                  SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Zorluk Seçici Chips
                        _buildDifficultySelector(isDark),

                        // Hedef Kartı & Durum Bilgisi
                        _buildTargetBanner(isDark),

                        // Aktif İşlem Formülü Önizleme
                        _buildFormulaPreviewBar(isDark),

                        // Kullanılabilir Sayılar Bölümü
                        _buildAvailableNumbersSection(isDark),

                        // 4 İşlem Operatör Butonları
                        _buildOperatorButtons(isDark),

                        // Kontrol Aksiyonları (Geri Al, Sıfırla, Pes Et)
                        _buildActionButtons(isDark),

                        const SizedBox(height: 6),

                        // İşlem Geçmişi (History)
                        _buildHistorySection(isDark),
                      ],
                    ),
                  ),

                  // Toast Bildirimi
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF333B46) : const Color(0xFF1E293B),
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
                                const Icon(Icons.info_outline_rounded, color: Color(0xFF2DD4BF), size: 18),
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

  /// Zorluk Seçici Chips
  Widget _buildDifficultySelector(bool isDark) {
    const difficulties = ['Kolay', 'Orta', 'Zor'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: difficulties.map((diff) {
            final isSelected = _currentDifficulty == diff;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(diff),
                selected: isSelected,
                onSelected: (val) {
                  if (val && _currentDifficulty != diff) {
                    _startNewGame(difficulty: diff);
                  }
                },
                selectedColor: const Color(0xFF0D9488),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Hedef Sayı Paneli
  Widget _buildTargetBanner(bool isDark) {
    final target = _puzzle?.target ?? 0;
    final closest = _closestValue;
    final diff = _closestDistance;
    final isMatched = diff == 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E3A3A), const Color(0xFF112222)]
              : [const Color(0xFFCCFBF1), const Color(0xFFE0F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMatched
              ? const Color(0xFF10B981)
              : const Color(0xFF0D9488).withValues(alpha: 0.4),
          width: isMatched ? 2.0 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'HEDEF SAYI',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: isDark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E),
                ),
              ),
              Text(
                '$target',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isMatched
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF263238) : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMatched ? Icons.check_circle_rounded : Icons.near_me_rounded,
                        size: 15,
                        color: isMatched ? Colors.white : const Color(0xFF0D9488),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          isMatched ? 'TAM HEDEF!' : 'En Yakın: $closest (Fark: $diff)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isMatched
                                ? Colors.white
                                : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Yapılan İşlem: ${_history.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Aktif Formül Önizleme Barı
  Widget _buildFormulaPreviewBar(bool isDark) {
    final num1 = _selectedFirstNumber?.value;
    final op = _selectedOperator;

    String promptText = 'İşlem yapmak için bir sayı seçin';
    if (num1 != null && op == null) {
      promptText = 'Şimdi bir işlem (+, -, ×, ÷) seçin';
    } else if (num1 != null && op != null) {
      promptText = 'İkinci sayıyı seçin';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? GameColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? GameColors.darkBorder : GameColors.lightBorder,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (num1 != null) ...[
            _buildBadge('$num1', const Color(0xFF0D9488)),
            const SizedBox(width: 8),
            if (op != null) ...[
              _buildBadge(op, const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildBadge('?', Colors.grey),
            ] else ...[
              const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  promptText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ),
            ],
          ] else ...[
            const Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF0D9488)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                promptText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Kullanılabilir Sayılar Listesi / Grid
  Widget _buildAvailableNumbersSection(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        alignment: WrapAlignment.center,
        children: _availableNumbers.map((item) {
          final isSelected = _selectedFirstNumber?.id == item.id;
          final isOriginal = item.isOriginal;

          return GestureDetector(
            onTap: () => _onNumberTap(item),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF0D9488)
                    : (isDark ? GameColors.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF0D9488)
                      : (isOriginal
                          ? (isDark ? GameColors.darkBorder : GameColors.lightBorder)
                          : const Color(0xFF2DD4BF)),
                  width: isSelected ? 2.5 : (isOriginal ? 1.2 : 2.0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? const Color(0xFF0D9488).withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '${item.value}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF1E293B)),
                      ),
                    ),
                  ),
                  if (!isOriginal)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2DD4BF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 4 İşlem Butonları (+, -, ×, ÷)
  Widget _buildOperatorButtons(bool isDark) {
    const operators = ['+', '-', '×', '÷'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: operators.map((op) {
          final isSelected = _selectedOperator == op;
          final isEnabled = _selectedFirstNumber != null;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Material(
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : (isDark ? const Color(0xFF333B46) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: isEnabled ? () => _onOperatorTap(op) : null,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: 50,
                  height: 44,
                  alignment: Alignment.center,
                  child: Text(
                    op,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : (isEnabled
                              ? (isDark ? Colors.white : const Color(0xFF1E293B))
                              : Colors.grey.withValues(alpha: 0.5)),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Geri Al, Sıfırla, Pes Et Aksiyonları
  Widget _buildActionButtons(bool isDark) {
    final canUndo = _history.isNotEmpty && !_isSuccess;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Geri Al
            TextButton.icon(
              onPressed: canUndo ? _onUndo : null,
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('Geri Al'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),

            // Sıfırla
            TextButton.icon(
              onPressed: canUndo ? _onReset : null,
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: const Text('Sıfırla'),
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 4),

            // Çözümü Gör
            TextButton.icon(
              onPressed: _showSolutionModal,
              icon: const Icon(Icons.lightbulb_outline_rounded, size: 18, color: Color(0xFFD97706)),
              label: const Text(
                'Çözümü Gör',
                style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 4),

            // Mevcut Sonuçla Bitir
            TextButton.icon(
              onPressed: _history.isNotEmpty ? _finishWithClosest : null,
              icon: const Icon(Icons.flag_rounded, size: 18, color: Color(0xFF0D9488)),
              label: const Text(
                'Bitir',
                style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Yapılan İşlemlerin Geçmişi
  Widget _buildHistorySection(bool isDark) {
    if (_history.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        alignment: Alignment.center,
        child: Text(
          'Henüz işlem yapılmadı.\nSayıları ve işlemleri seçerek başlayın.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'İŞLEM GEÇMİŞİ (${_history.length})',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
              Text(
                'Kalan Sayı: ${_availableNumbers.length}',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
          const Divider(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final step = _history[index];
                final isLast = index == _history.length - 1;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isLast
                        ? (isDark ? const Color(0xFF1E3A3A) : const Color(0xFFF0FDFA))
                        : (isDark ? const Color(0xFF333B46) : const Color(0xFFF8FAFC)),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isLast
                          ? const Color(0xFF0D9488).withValues(alpha: 0.6)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 11,
                        backgroundColor: isLast
                            ? const Color(0xFF0D9488)
                            : (isDark ? Colors.white24 : Colors.black26),
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        step.formatted,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      if (isLast)
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 16, color: Color(0xFF0D9488)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
