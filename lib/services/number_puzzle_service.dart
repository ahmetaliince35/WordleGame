import 'dart:math';

class PuzzleStep {
  final int num1;
  final String operator;
  final int num2;
  final int result;

  const PuzzleStep({
    required this.num1,
    required this.operator,
    required this.num2,
    required this.result,
  });

  String get formatted => '$num1 $operator $num2 = $result';
}

class NumberPuzzle {
  final int target;
  final List<int> startingNumbers;
  final String difficulty;
  final List<PuzzleStep> solutionSteps;

  const NumberPuzzle({
    required this.target,
    required this.startingNumbers,
    required this.difficulty,
    required this.solutionSteps,
  });
}

class SolverResult {
  final bool isExact;
  final int closestValue;
  final List<PuzzleStep> steps;

  const SolverResult({
    required this.isExact,
    required this.closestValue,
    required this.steps,
  });
}

class _OpCandidate {
  final int num1;
  final String op;
  final int num2;
  final int result;

  const _OpCandidate(this.num1, this.op, this.num2, this.result);
}

class NumberPuzzleService {
  static final NumberPuzzleService _instance = NumberPuzzleService._internal();
  factory NumberPuzzleService() => _instance;
  NumberPuzzleService._internal();

  final Random _random = Random();

  /// Verilen sayılar ve hedef için en kısa 4 işlem çözümünü bulur.
  SolverResult solve(List<int> initialNumbers, int target) {
    if (initialNumbers.contains(target)) {
      return SolverResult(isExact: true, closestValue: target, steps: const []);
    }

    int bestDistance = 999999;
    int bestValue = initialNumbers.isNotEmpty ? initialNumbers.first : 0;
    List<PuzzleStep> bestSteps = [];

    for (final n in initialNumbers) {
      final dist = (n - target).abs();
      if (dist < bestDistance) {
        bestDistance = dist;
        bestValue = n;
      }
    }

    bool foundExact = false;

    void search(List<int> currentNumbers, List<PuzzleStep> currentSteps) {
      if (foundExact) return;

      final count = currentNumbers.length;
      if (count < 2) return;

      for (int i = 0; i < count; i++) {
        for (int j = i + 1; j < count; j++) {
          final a = currentNumbers[i];
          final b = currentNumbers[j];

          final remaining = <int>[];
          for (int k = 0; k < count; k++) {
            if (k != i && k != j) remaining.add(currentNumbers[k]);
          }

          final candidates = <_OpCandidate>[];

          // 1. Toplama (+)
          candidates.add(_OpCandidate(a >= b ? a : b, '+', a >= b ? b : a, a + b));

          // 2. Çarpma (×) - 1 ile çarpmak yeni bir değer üretmediği için atlanır
          if (a > 1 && b > 1) {
            final mult = a * b;
            if (mult <= 10000) {
              candidates.add(_OpCandidate(a >= b ? a : b, '×', a >= b ? b : a, mult));
            }
          }

          // 3. Çıkarma (-) - Yalnızca pozitif tam sayılar (a != b)
          if (a > b) {
            candidates.add(_OpCandidate(a, '-', b, a - b));
          } else if (b > a) {
            candidates.add(_OpCandidate(b, '-', a, b - a));
          }

          // 4. Bölme (÷) - Yalnızca tam bölünen pozitif tam sayılar (kalan = 0, bölen > 1)
          if (b > 1 && a % b == 0) {
            candidates.add(_OpCandidate(a, '÷', b, a ~/ b));
          } else if (a > 1 && b % a == 0) {
            candidates.add(_OpCandidate(b, '÷', a, b ~/ a));
          }

          for (final op in candidates) {
            final res = op.result;
            final step = PuzzleStep(
              num1: op.num1,
              operator: op.op,
              num2: op.num2,
              result: res,
            );

            final nextSteps = [...currentSteps, step];
            final dist = (res - target).abs();

            if (dist < bestDistance) {
              bestDistance = dist;
              bestValue = res;
              bestSteps = nextSteps;
              if (dist == 0) {
                foundExact = true;
                return;
              }
            }

            if (nextSteps.length < 5 && !foundExact) {
              search([...remaining, res], nextSteps);
              if (foundExact) return;
            }
          }
        }
      }
    }

    search(initialNumbers, []);

    return SolverResult(
      isExact: bestDistance == 0,
      closestValue: bestValue,
      steps: bestSteps,
    );
  }

  /// Belirtilen zorluk seviyesine göre rastgele ve kesin çözümü olan bir bulmaca üretir.
  NumberPuzzle generatePuzzle({String difficulty = 'Orta'}) {
    int targetMin;
    int targetMax;
    int numCount;

    switch (difficulty) {
      case 'Kolay':
        numCount = 5;
        targetMin = 50;
        targetMax = 250;
        break;
      case 'Zor':
        numCount = 6;
        targetMin = 150;
        targetMax = 999;
        break;
      case 'Orta':
      default:
        numCount = 6;
        targetMin = 100;
        targetMax = 500;
        break;
    }

    // Kullanıcı kuralı: Sayılar max 50'ye kadar olmalı
    // Tekrarlanan denemelerle kesin çözümü olan bir soru bulunur
    for (int attempt = 0; attempt < 60; attempt++) {
      final numbers = <int>[];

      // Küçük sayılar (1 - 10)
      final smallPool = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      smallPool.shuffle(_random);
      final smallCount = (numCount == 5) ? 3 : 4;
      for (int i = 0; i < smallCount; i++) {
        numbers.add(smallPool[i]);
      }

      // Büyük sayılar (max 50'ye kadar: 15, 20, 25, 30, 40, 50)
      final largePool = [15, 20, 25, 30, 40, 50];
      largePool.shuffle(_random);
      final largeCount = numCount - smallCount;
      for (int i = 0; i < largeCount; i++) {
        numbers.add(largePool[i]);
      }

      numbers.shuffle(_random);

      // Sayılardan geçerli birkaç işlem simüle ederek kesin ulaşılabilir bir hedef türet
      final simNumbers = List<int>.from(numbers);
      int simulatedTarget = 0;
      final simStepsCount = (difficulty == 'Kolay') ? 2 + _random.nextInt(2) : 3 + _random.nextInt(2);

      for (int s = 0; s < simStepsCount && simNumbers.length >= 2; s++) {
        simNumbers.shuffle(_random);
        final a = simNumbers.removeLast();
        final b = simNumbers.removeLast();
        final ops = ['+', '-', '×', '÷']..shuffle(_random);

        int? r;
        for (final op in ops) {
          if (op == '+') {
            r = a + b;
            break;
          } else if (op == '×' && a > 1 && b > 1 && a * b <= 1000) {
            r = a * b;
            break;
          } else if (op == '-' && a != b) {
            r = (a > b) ? a - b : b - a;
            break;
          } else if (op == '÷') {
            if (b > 1 && a % b == 0) {
              r = a ~/ b;
              break;
            } else if (a > 1 && b % a == 0) {
              r = b ~/ a;
              break;
            }
          }
        }

        if (r != null && r > 0) {
          simNumbers.add(r);
          if (r >= targetMin && r <= targetMax) {
            simulatedTarget = r;
          }
        }
      }

      if (simulatedTarget >= targetMin && simulatedTarget <= targetMax) {
        final sol = solve(numbers, simulatedTarget);
        if (sol.isExact) {
          return NumberPuzzle(
            target: simulatedTarget,
            startingNumbers: numbers,
            difficulty: difficulty,
            solutionSteps: sol.steps,
          );
        }
      }
    }

    // Yedek güvenli bulmaca (her zaman geçerli)
    final fallbackNumbers = [3, 5, 8, 10, 25, 50];
    const fallbackTarget = 243;
    final fallbackSol = solve(fallbackNumbers, fallbackTarget);

    return NumberPuzzle(
      target: fallbackTarget,
      startingNumbers: fallbackNumbers,
      difficulty: difficulty,
      solutionSteps: fallbackSol.steps,
    );
  }
}
