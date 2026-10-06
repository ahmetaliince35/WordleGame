import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelime_dunyasi/main.dart';
import 'package:kelime_dunyasi/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseService().initialize();
  });

  testWidgets('GameHub screen initial UI smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const WordleApp());
    await tester.pump();

    // Verify main hub titles and game cards
    expect(find.text('Kelime Dünyası'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Türkçe Wordle'), findsOneWidget);
    expect(find.text('Kelime Türetmece'), findsOneWidget);
    expect(find.text('Adam Asmaca'), findsOneWidget);
    expect(find.text('Anagram Çözücü'), findsOneWidget);
  });
}
