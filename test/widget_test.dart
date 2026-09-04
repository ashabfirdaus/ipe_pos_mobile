import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ipe_mobile_pos/core/config/app_config.dart';
import 'package:ipe_mobile_pos/core/services/storage_service.dart';
import 'package:ipe_mobile_pos/main.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  testWidgets('App launches, displays Splash, and navigates to LoginPage when no token', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // 1. Initial screen: Verify SplashPage renders AppName
    expect(find.text(AppConfig.appName), findsOneWidget);

    // 2. Advance time past splash timer (2 seconds) and settle navigation
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 3. Verify LoginPage has loaded because no token is saved
    expect(find.text('Masuk Akun Kasir'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
  });
}
