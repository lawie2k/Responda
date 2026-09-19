import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/features/onboarding/presentation/screens/language_selection_screen.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/screens/online/main_shell.dart';
import 'package:responda/screens/online/reporting/add_photo_screen.dart';
import 'package:responda/screens/online/reporting/incident_location_screen.dart';
import 'package:responda/screens/online/reporting/incident_type_screen.dart';
import 'package:responda/screens/online/reporting/report_details_screen.dart';
import 'package:responda/screens/online/reporting/report_success_screen.dart';
import 'package:responda/screens/online/reporting/review_report_screen.dart';
import 'package:responda/screens/online/reporting/submitting_report_screen.dart';

void main() {
  const completeDraft = ReportDraft(
    incidentType: IncidentType.accident,
    latitude: 7.135421,
    longitude: 125.912300,
    locationAccuracy: 8,
    landmark: 'Kingking Highway',
    description: 'A person needs help.',
    morePeople: true,
    additionalAssistance: false,
    stillDangerous: true,
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Future<void> pumpPhoneScreen(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(MaterialApp(key: UniqueKey(), home: screen));
    await tester.pump();
  }

  testWidgets('renders language onboarding screen', (tester) async {
    await pumpPhoneScreen(tester, const LanguageSelectionScreen());
    expect(
      find.text(
        'Choose your language\nPilia ang imong pinulongan\nPiliin ang iyong wika',
      ),
      findsOneWidget,
    );
  });

  testWidgets('renders the online home screen', (tester) async {
    await pumpPhoneScreen(tester, const MainShell());
    expect(find.text('Need Emergency\nAssistance?'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);

    final navigation = find.byType(RespondaBottomNavigation);
    expect(tester.getSize(navigation).width, 390);
    expect(tester.getBottomRight(navigation).dy, 844);
  });

  testWidgets('renders every screen in the online report flow', (tester) async {
    await pumpPhoneScreen(tester, const IncidentTypeScreen());
    expect(find.text('What happened?'), findsOneWidget);

    await pumpPhoneScreen(
      tester,
      IncidentLocationScreen(
        draft: const ReportDraft(incidentType: IncidentType.accident),
        loadLocation: () async => DeviceLocationData(
          latitude: 7.135421,
          longitude: 125.912300,
          accuracy: 8,
          timestamp: DateTime(2026, 8, 31, 9, 41),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Incident Location'), findsOneWidget);

    await pumpPhoneScreen(
      tester,
      const ReportDetailsScreen(draft: completeDraft),
    );
    expect(find.text('Quick Details'), findsOneWidget);

    await pumpPhoneScreen(tester, const AddPhotoScreen(draft: completeDraft));
    expect(find.text('Add a Photo'), findsOneWidget);

    await pumpPhoneScreen(
      tester,
      const ReviewReportScreen(draft: completeDraft),
    );
    expect(find.text('Review Your Report'), findsOneWidget);

    await pumpPhoneScreen(
      tester,
      const SubmittingReportScreen(draft: completeDraft),
    );
    expect(find.text('Sending your report to MDRRMO…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(const Duration(milliseconds: 500));

    await pumpPhoneScreen(
      tester,
      ReportSuccessScreen(
        draft: completeDraft,
        submittedAt: DateTime(2026, 8, 31, 9, 41),
      ),
    );
    expect(find.text('REPORT SENT'), findsOneWidget);
    expect(find.text('People Involved'), findsNothing);
  });

  testWidgets('quick incident opens location with its incident type', (
    tester,
  ) async {
    await pumpPhoneScreen(tester, const MainShell());

    await tester.tap(find.text('Accident'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Incident Location'), findsOneWidget);
    expect(find.text('What happened?'), findsNothing);
    final locationScreen = tester.widget<IncidentLocationScreen>(
      find.byType(IncidentLocationScreen),
    );
    expect(locationScreen.draft.incidentType, IncidentType.accident);
    expect(IncidentType.accident.apiValue, 'road_accident');
  });

  testWidgets('requires every reporting step before continuing', (
    tester,
  ) async {
    await pumpPhoneScreen(tester, const MainShell());
    await tester.tap(find.text('REPORT AN EMERGENCY'));
    await tester.pumpAndSettle();

    expect(find.text('What happened?'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Road Accident'));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Incident Location'), findsOneWidget);

    await pumpPhoneScreen(
      tester,
      IncidentLocationScreen(
        draft: const ReportDraft(incidentType: IncidentType.accident),
        loadLocation: () async => DeviceLocationData(
          latitude: 7.135421,
          longitude: 125.912300,
          accuracy: 8,
          timestamp: DateTime(2026, 8, 31, 9, 41),
        ),
      ),
    );
    await tester.pump();
    final useLocationButton = find.widgetWithText(
      FilledButton,
      'Use This Location',
    );
    expect(tester.widget<FilledButton>(useLocationButton).onPressed, isNotNull);

    await pumpPhoneScreen(
      tester,
      const ReportDetailsScreen(
        draft: ReportDraft(
          incidentType: IncidentType.accident,
          latitude: 7.135421,
          longitude: 125.912300,
          locationAccuracy: 8,
        ),
      ),
    );
    var continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'A person needs help.');
    final yesButtons = find.widgetWithText(FilledButton, 'Yes');
    for (var index = 0; index < 3; index++) {
      await tester.ensureVisible(yesButtons.at(index));
      await tester.tap(yesButtons.at(index));
      await tester.pump();
    }
    continueButton = find.widgetWithText(FilledButton, 'Continue');
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNotNull);

    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();
    expect(find.text('Add a Photo'), findsOneWidget);
    expect(find.text('People Involved'), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Skip for now'));
    await tester.pumpAndSettle();
    expect(find.text('Review Your Report'), findsOneWidget);
  });

  testWidgets('switches tab content while keeping one bottom navigation', (
    tester,
  ) async {
    await pumpPhoneScreen(tester, const MainShell());

    final navigation = find.byType(RespondaBottomNavigation);
    final originalNavigationElement = tester.element(navigation);
    expect(find.byType(Scrollable), findsNothing);

    await tester.tap(find.text('My Reports'));
    await tester.pump();
    expect(find.text('Track reports sent from this device'), findsOneWidget);
    final reportCardsScroll = find.byKey(const Key('report_cards_scroll_view'));
    expect(reportCardsScroll, findsOneWidget);
    expect(
      find.ancestor(of: find.text('Active'), matching: reportCardsScroll),
      findsNothing,
    );
    expect(tester.element(navigation), same(originalNavigationElement));

    await tester.tap(find.text('Emergency Info'));
    await tester.pump();
    expect(find.text('Emergency Information'), findsOneWidget);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(tester.element(navigation), same(originalNavigationElement));

    await tester.tap(find.text('Settings'));
    await tester.pump();
    expect(find.text('Language used throughout the app'), findsOneWidget);
    expect(find.text('SMS fallback'), findsNothing);
    expect(find.byType(Scrollable), findsNothing);
    expect(tester.element(navigation), same(originalNavigationElement));
    expect(tester.getSize(navigation).width, 390);
    expect(tester.getBottomRight(navigation).dy, 844);
  });
}
