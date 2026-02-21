// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:know_you/main.dart';
import 'package:know_you/common/floating_ball_service.dart';
import 'package:know_you/common/shizuku_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        floatingBallService: FloatingBallService(),
        shizukuService: ShizukuService(),
      ),
    );

    // Let initial frames settle; avoid asserting specific UI here.
    await tester.pump(const Duration(milliseconds: 100));
  });
}
