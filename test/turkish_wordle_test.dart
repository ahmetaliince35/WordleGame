import 'package:flutter_test/flutter_test.dart';

String toTurkishUpper(String text) {
  return text
      .replaceAll('â', 'A')
      .replaceAll('Â', 'A')
      .replaceAll('î', 'İ')
      .replaceAll('Î', 'İ')
      .replaceAll('û', 'U')
      .replaceAll('Û', 'U')
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .replaceAll('ç', 'Ç')
      .replaceAll('ğ', 'Ğ')
      .replaceAll('ö', 'Ö')
      .replaceAll('ş', 'Ş')
      .replaceAll('ü', 'Ü')
      .toUpperCase();
}

String toTurkishLower(String text) {
  return text
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .replaceAll('Ç', 'ç')
      .replaceAll('Ğ', 'ğ')
      .replaceAll('Ö', 'ö')
      .replaceAll('Ş', 'ş')
      .replaceAll('Ü', 'ü')
      .toLowerCase();
}

enum LetterEvaluation { empty, notInWord, wrongPosition, correctPosition }

List<LetterEvaluation> evaluateGuess(String guess, String target) {
  final length = target.length;
  final result = List<LetterEvaluation>.filled(length, LetterEvaluation.notInWord);
  final targetLetters = target.split('');
  final guessLetters = guess.split('');

  // Frequency count for non-exact letters in target
  final remainingCounts = <String, int>{};

  // Pass 1: find exact matches
  for (int i = 0; i < length; i++) {
    if (guessLetters[i] == targetLetters[i]) {
      result[i] = LetterEvaluation.correctPosition;
    } else {
      final char = targetLetters[i];
      remainingCounts[char] = (remainingCounts[char] ?? 0) + 1;
    }
  }

  // Pass 2: find wrong position matches
  for (int i = 0; i < length; i++) {
    if (result[i] == LetterEvaluation.correctPosition) continue;

    final char = guessLetters[i];
    final count = remainingCounts[char] ?? 0;
    if (count > 0) {
      result[i] = LetterEvaluation.wrongPosition;
      remainingCounts[char] = count - 1;
    } else {
      result[i] = LetterEvaluation.notInWord;
    }
  }

  return result;
}

void main() {
  test('Turkish uppercase works accurately', () {
    expect(toTurkishUpper('kitap'), equals('KİTAP'));
    expect(toTurkishUpper('ışık'), equals('IŞIK'));
    expect(toTurkishUpper('çiçek'), equals('ÇİÇEK'));
    expect(toTurkishUpper('ağaç'), equals('AĞAÇ'));
    expect(toTurkishUpper('öykü'), equals('ÖYKÜ'));
    expect(toTurkishUpper('şeker'), equals('ŞEKER'));
    expect(toTurkishUpper('üzüm'), equals('ÜZÜM'));
    expect(toTurkishUpper('kâtip'), equals('KATİP'));
  });

  test('Wordle duplicate letter evaluation', () {
    // Target: ELMA, Guess: ESER -> first E green, second E gray
    final res1 = evaluateGuess('ESER', 'ELMA');
    expect(res1, equals([
      LetterEvaluation.correctPosition,
      LetterEvaluation.notInWord,
      LetterEvaluation.notInWord,
      LetterEvaluation.notInWord,
    ]));

    // Target: MELEK (ends in K), Guess: KEKİK (ends in K) ->
    // Pass 1: guess[1] ('E') is correctPosition, guess[4] ('K') is correctPosition.
    // remaining: M:1, E:1, L:1. 'K' remaining is 0!
    // Pass 2:
    // guess[0] 'K' -> remaining 0, so notInWord
    // guess[2] 'K' -> remaining 0, so notInWord
    // guess[3] 'İ' -> notInWord
    final res2 = evaluateGuess('KEKİK', 'MELEK');
    expect(res2, equals([
      LetterEvaluation.notInWord,
      LetterEvaluation.correctPosition,
      LetterEvaluation.notInWord,
      LetterEvaluation.notInWord,
      LetterEvaluation.correctPosition,
    ]));

    // Target: MELEK, Guess: KELAM ->
    // K at 0 (target has K at 4) -> wrongPosition
    // E at 1 (target has E at 1) -> correctPosition
    // L at 2 (target has L at 2) -> correctPosition
    // A at 3 -> notInWord
    // M at 4 (target has M at 0) -> wrongPosition
    final res3 = evaluateGuess('KELAM', 'MELEK');
    expect(res3, equals([
      LetterEvaluation.wrongPosition,
      LetterEvaluation.correctPosition,
      LetterEvaluation.correctPosition,
      LetterEvaluation.notInWord,
      LetterEvaluation.wrongPosition,
    ]));
  });
}
