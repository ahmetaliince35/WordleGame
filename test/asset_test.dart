import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test loading asset data/sozluk.db', () async {
    final data = await rootBundle.load('data/sozluk.db');
    expect(data.lengthInBytes, greaterThan(1000));
  });
}
