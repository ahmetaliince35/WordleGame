/// Helper class for Turkish language string manipulation and normalization.
class TurkishHelper {
  /// 29 standard Turkish letters
  static const Set<String> turkishAlphabet = {
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H',
    'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P',
    'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
  };

  /// Full Q keyboard alphabet including Q, W, X for input
  static const Set<String> validAlphabet = {
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H',
    'I', 'İ', 'J', 'K', 'L', 'M', 'N', 'O', 'Ö', 'P',
    'Q', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'W', 'X',
    'Y', 'Z',
  };

  /// Normalizes a Turkish word for Wordle:
  /// - Strips circumflexes (â->A, î->İ, û->U)
  /// - Converts lowercase Turkish letters correctly: i->İ, ı->I, etc.
  /// - Converts to uppercase
  static String toTurkishUpper(String text) {
    var s = text.trim();
    // Replace circumflex letters
    s = s.replaceAll('â', 'a').replaceAll('Â', 'A')
         .replaceAll('î', 'i').replaceAll('Î', 'İ')
         .replaceAll('û', 'u').replaceAll('Û', 'U')
         .replaceAll('é', 'e').replaceAll('É', 'E');

    // Handle Turkish specific casing
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final char = s[i];
      switch (char) {
        case 'i':
          sb.write('İ');
          break;
        case 'ı':
          sb.write('I');
          break;
        case 'ç':
          sb.write('Ç');
          break;
        case 'ğ':
          sb.write('Ğ');
          break;
        case 'ö':
          sb.write('Ö');
          break;
        case 'ş':
          sb.write('Ş');
          break;
        case 'ü':
          sb.write('Ü');
          break;
        default:
          sb.write(char.toUpperCase());
      }
    }
    return sb.toString();
  }

  /// Converts Turkish uppercase to lowercase properly:
  /// İ -> i, I -> ı
  static String toTurkishLower(String text) {
    final sb = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      switch (char) {
        case 'İ':
          sb.write('i');
          break;
        case 'I':
          sb.write('ı');
          break;
        case 'Ç':
          sb.write('ç');
          break;
        case 'Ğ':
          sb.write('ğ');
          break;
        case 'Ö':
          sb.write('ö');
          break;
        case 'Ş':
          sb.write('ş');
          break;
        case 'Ü':
          sb.write('ü');
          break;
        default:
          sb.write(char.toLowerCase());
      }
    }
    return sb.toString();
  }

  /// Checks if a string consists only of valid 29 Turkish uppercase letters.
  static bool isValidTurkishWord(String word, int expectedLength) {
    if (word.length != expectedLength) return false;
    for (int i = 0; i < word.length; i++) {
      if (!turkishAlphabet.contains(word[i])) {
        return false;
      }
    }
    return true;
  }
}
