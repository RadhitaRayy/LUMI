import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/app.dart';
import 'package:lumi/data/mock_data.dart';
import 'package:lumi/data/models.dart';
import 'package:lumi/features/auth/auth_widgets.dart';
import 'package:lumi/theme/app_theme.dart';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LumiApp());
    await tester.pumpAndSettle();
  }

  Future<void> login(WidgetTester tester) async {
    await tester.enterText(find.byType(TextFormField).at(0), 'saya@email.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.tap(find.text('Masuk'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
  }

  testWidgets('login menolak form kosong', (tester) async {
    await pumpApp(tester);
    expect(find.text('Selamat datang lagi'), findsOneWidget);

    await tester.tap(find.text('Masuk'));
    await tester.pump();
    expect(find.text('Email wajib diisi'), findsOneWidget);
    expect(find.text('Password wajib diisi'), findsOneWidget);
  });

  testWidgets('login valid membuka chat', (tester) async {
    await pumpApp(tester);
    await login(tester);
    expect(find.text('Terhubung ke ${MockData.hostName}'), findsOneWidget);
    expect(find.text('Menunggu izin'), findsOneWidget);
  });

  testWidgets('izinkan aksi menjalankan restart', (tester) async {
    await pumpApp(tester);
    await login(tester);

    await tester.tap(find.text('Tinjau'));
    await tester.pumpAndSettle();
    expect(find.text('Izinkan aksi ini?'), findsOneWidget);

    await tester.tap(find.text('Izinkan sekali'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text('Diizinkan'), findsOneWidget);
    expect(find.textContaining('Beres. bot-discord'), findsOneWidget);
  });

  testWidgets('kirim pesan memanggil tool status', (tester) async {
    await pumpApp(tester);
    await login(tester);

    await tester.enterText(find.byType(TextField).last, 'status bot dong');
    await tester.tap(find.byTooltip('Kirim'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Semua bot online dan sehat.'), findsOneWidget);
  });

  test('kekuatan password', () {
    expect(passwordStrength('abc'), 0);
    expect(passwordStrength('abcdefgh'), 1);
    expect(passwordStrength('abcdefg1'), 2);
    expect(passwordStrength('Abcdefg1'), 3);
  });

  test('mode izin punya label', () {
    expect(PermissionMode.auto.label, 'Otomatis');
    expect(PermissionMode.ask.label, 'Minta izin');
  });
}
