import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:possession_tracker/core/services/local_database_service.dart';
import 'package:possession_tracker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('widget_test_');
    await LocalDatabaseService.instance.init(customPath: '${tempDir.path}/test_db.json');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets('App launches and displays Storage Hierarchy smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(child: PossessionTrackerApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Storage Hierarchy'), findsOneWidget);
    expect(find.text('Storage'), findsWidgets);
    expect(find.text('Items'), findsWidgets);
    expect(find.text('Locator'), findsWidgets);
  });

  testWidgets('Storage Hierarchy displays tiled locations and allows toggling to list view', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      const ProviderScope(child: PossessionTrackerApp()),
    );
    await tester.pumpAndSettle();

    // Verify GridView is used for tiled display
    expect(find.byType(GridView), findsOneWidget);
    expect(find.text('Workshop & Garage'), findsOneWidget);

    // Verify metric badges
    expect(find.textContaining('Area'), findsWidgets);
    expect(find.textContaining('Item'), findsWidgets);

    // Tap layout toggle button to switch to List View
    final toggleButton = find.byTooltip('Switch to List View');
    expect(toggleButton, findsOneWidget);
    await tester.tap(toggleButton);
    await tester.pumpAndSettle();

    // Verify ListView is now displayed
    expect(find.byType(ListView), findsOneWidget);
    expect(find.byTooltip('Switch to Grid Tiles'), findsOneWidget);
  });
}
