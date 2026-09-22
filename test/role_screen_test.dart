import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rider_app/screens/role_selection_screen.dart';
import 'package:rider_app/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('RoleSelectionScreen builds and shows all role cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: RoleSelectionScreen(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('SwiftDrop'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(find.text('Customer signup'), findsOneWidget);
    expect(find.text('Rider signup'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SplashScreen navigates to RoleSelectionScreen when logged out', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: SplashScreen(),
      ),
    );

    // Initial splash frame
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(SplashScreen), findsOneWidget);

    // Advance beyond the 3500ms delay in _startSequence
    await tester.pump(const Duration(milliseconds: 3600));
    // Settle the navigation transition
    await tester.pump(const Duration(milliseconds: 700));

    // RoleSelectionScreen should now be present on screen!
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Rider'), findsOneWidget);
    expect(find.text('Business'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
