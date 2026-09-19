import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:responda/core/widgets/responda_bottom_navigation.dart';

void main() {
  Future<void> pumpNavigation(
    WidgetTester tester, {
    PhoneLauncher? phoneLauncher,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: Material(
            child: SafeArea(
              top: false,
              child: RespondaBottomNavigation(
                activeItem: RespondaNavItem.home,
                phoneLauncher: phoneLauncher,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('center call button opens the GPS warning sheet', (tester) async {
    await pumpNavigation(tester);

    expect(find.text('Call'), findsOneWidget);
    await tester.tap(find.byKey(const Key('emergency_call_nav_button')));
    await tester.pumpAndSettle();

    expect(find.text('Call MDRRMO?'), findsOneWidget);
    expect(
      find.textContaining('will not send your accurate GPS'),
      findsOneWidget,
    );
    expect(find.text('09476236516'), findsOneWidget);
    expect(find.text('Open Phone App'), findsOneWidget);
  });

  testWidgets('phone app receives the MDRRMO number without placing a call', (
    tester,
  ) async {
    Uri? launchedUri;
    await pumpNavigation(
      tester,
      phoneLauncher: (uri) async {
        launchedUri = uri;
        return true;
      },
    );

    await tester.tap(find.byKey(const Key('emergency_call_nav_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open_phone_app_button')));
    await tester.pumpAndSettle();

    expect(launchedUri, Uri(scheme: 'tel', path: '09476236516'));
    expect(find.text('Call MDRRMO?'), findsNothing);
  });
}
