import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/main.dart';

void main() {
  testWidgets('App basic smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ExpenseTrackerApp());

    // Verify that the title is present.
    expect(find.text('Expense Tracker'), findsOneWidget);

    // Verify that the initial empty state message is present.
    expect(find.text('No clients added yet.'), findsOneWidget);
  });
}
