import 'package:flutter_test/flutter_test.dart';
import 'package:movie_tracker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows authentication screen on a fresh local install', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MovieTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('ورود به فیلم‌یار'), findsOneWidget);
    expect(find.text('ادامه به‌عنوان مهمان'), findsOneWidget);
  });
}
