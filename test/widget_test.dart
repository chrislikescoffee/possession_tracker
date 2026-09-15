import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/main.dart';

void main() {
  testWidgets('App launches and displays Storage Hierarchy smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: PossessionTrackerApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storage Hierarchy'), findsOneWidget);
    expect(find.text('Storage'), findsWidgets);
    expect(find.text('Items'), findsWidgets);
    expect(find.text('Locator'), findsWidgets);
  });
}
