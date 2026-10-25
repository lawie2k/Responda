import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/theme/app_colors.dart';
import 'package:responda/features/reporting/data/offline_report_store.dart';
import 'package:responda/features/reporting/data/offline_sms_handoff.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';
import 'package:responda/screens/offline/offline_main_shell.dart';
import 'package:responda/screens/offline/offline_sms_gateway_screen.dart';
import 'package:responda/screens/shared/reporting/incident_location_screen.dart';
import 'package:responda/screens/shared/reporting/report_details_screen.dart';
import 'package:responda/screens/shared/reporting/submitting_report_screen.dart';

void main() {
  const completeDraft = ReportDraft(
    incidentType: IncidentType.accident,
    latitude: 7.135421,
    longitude: 125.912300,
    locationAccuracy: 8,
    description: 'A person needs help.',
    morePeople: true,
    additionalAssistance: false,
    stillDangerous: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPhoneScreen(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pump();
  }

  testWidgets('offline home keeps its content without a connection badge', (
    tester,
  ) async {
    await pumpPhoneScreen(tester, const OfflineMainShell());
    expect(find.text('Offline'), findsNothing);
    expect(find.text('Online'), findsNothing);
    expect(find.text('Current GPS Location'), findsOneWidget);
  });

  testWidgets('offline report opens the SMS gateway before the report form', (
    tester,
  ) async {
    await pumpPhoneScreen(tester, const OfflineMainShell());

    await tester.tap(find.text('REPORT AN EMERGENCY'));
    await tester.pumpAndSettle();

    expect(find.byType(OfflineSmsGatewayScreen), findsOneWidget);
    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('SMS can still reach\nhelp'), findsOneWidget);
    expect(find.text('Continue with SMS'), findsOneWidget);
    expect(find.byKey(const Key('offline_gateway_sprite')), findsOneWidget);
    expect(find.text('What happened?'), findsNothing);

    await tester.tap(find.byKey(const Key('continue_with_sms_button')));
    await tester.pumpAndSettle();
    expect(find.text('What happened?'), findsOneWidget);
  });

  testWidgets('offline GPS step shows coordinates without an online map', (
    tester,
  ) async {
    await pumpPhoneScreen(
      tester,
      const IncidentLocationScreen(
        draft: completeDraft,
        flowMode: ReportFlowMode.offline,
      ),
    );

    expect(find.text('GPS works without internet'), findsOneWidget);
    expect(find.textContaining('7.135421'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Landmark'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byKey(const Key('landmark_input'))).enabled,
      isFalse,
    );
    expect(_gpsCardColor(tester), AppColors.successSoft);
  });

  testWidgets('landmark field unlocks only from its manual entry button', (
    tester,
  ) async {
    await pumpPhoneScreen(
      tester,
      const IncidentLocationScreen(
        draft: completeDraft,
        flowMode: ReportFlowMode.offline,
      ),
    );

    final landmarkInput = find.byKey(const Key('landmark_input'));
    var field = tester.widget<TextField>(landmarkInput);
    expect(field.enabled, isFalse);

    await tester.tap(landmarkInput);
    await tester.pump();
    expect(field.focusNode?.hasFocus, isFalse);

    final enableButton = find.byKey(const Key('enable_landmark_input_button'));
    await tester.ensureVisible(enableButton);
    await tester.tap(enableButton);
    await tester.pump();
    await tester.pump();

    field = tester.widget<TextField>(landmarkInput);
    expect(field.enabled, isTrue);
    expect(field.focusNode?.hasFocus, isTrue);

    await tester.enterText(landmarkInput, 'Barangay Hall');
    expect(find.text('Barangay Hall'), findsOneWidget);
  });

  testWidgets('offline GPS warns when accuracy is between 50 and 200 meters', (
    tester,
  ) async {
    await pumpPhoneScreen(
      tester,
      const IncidentLocationScreen(
        draft: ReportDraft(
          incidentType: IncidentType.accident,
          latitude: 7.129329,
          longitude: 125.898422,
          locationAccuracy: 120,
        ),
        flowMode: ReportFlowMode.offline,
      ),
    );

    expect(find.text('Low GPS accuracy'), findsNWidgets(2));
    expect(find.byKey(const Key('low_gps_accuracy_warning')), findsOneWidget);
    expect(find.textContaining('(±120 m)'), findsOneWidget);
    expect(find.textContaining('Enter a nearby landmark'), findsOneWidget);
    expect(_gpsCardColor(tester), AppColors.warningSoft);
    expect(
      find.byKey(const Key('very_low_gps_accuracy_warning')),
      findsNothing,
    );
  });

  testWidgets('offline GPS strongly warns at 200 meters or worse', (
    tester,
  ) async {
    await pumpPhoneScreen(
      tester,
      const IncidentLocationScreen(
        draft: ReportDraft(
          incidentType: IncidentType.accident,
          latitude: 7.129329,
          longitude: 125.898422,
          locationAccuracy: 200,
        ),
        flowMode: ReportFlowMode.offline,
      ),
    );

    expect(find.text('Very low GPS accuracy'), findsNWidgets(2));
    expect(
      find.byKey(const Key('very_low_gps_accuracy_warning')),
      findsOneWidget,
    );
    expect(find.textContaining('(±200 m)'), findsOneWidget);
    expect(find.textContaining('Enter a clear landmark'), findsOneWidget);
    expect(_gpsCardColor(tester), AppColors.dangerSoft);
    expect(find.byKey(const Key('low_gps_accuracy_warning')), findsNothing);
  });

  testWidgets('offline GPS keeps searching for a satellite-only fix', (
    tester,
  ) async {
    final location = Completer<DeviceLocationData>();
    await pumpPhoneScreen(
      tester,
      IncidentLocationScreen(
        draft: const ReportDraft(incidentType: IncidentType.accident),
        flowMode: ReportFlowMode.offline,
        loadLocation: () => location.future,
      ),
    );

    expect(
      find.textContaining('searches for up to 90 seconds'),
      findsOneWidget,
    );
    expect(find.textContaining('Without cellular signal'), findsOneWidget);

    location.complete(
      DeviceLocationData(
        latitude: 7.129329,
        longitude: 125.898422,
        accuracy: 20,
        timestamp: DateTime(2026, 9, 24),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('7.129329'), findsOneWidget);
  });

  testWidgets('offline details skip the photo screen and open review', (
    tester,
  ) async {
    await pumpPhoneScreen(
      tester,
      const ReportDetailsScreen(
        draft: completeDraft,
        flowMode: ReportFlowMode.offline,
      ),
    );
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.text('Review Your Report'), findsOneWidget);
    expect(find.text('Add a Photo'), findsNothing);
    expect(find.text('Offline SMS handoff'), findsOneWidget);
    expect(find.text('SAVE REPORT & OPEN SMS'), findsOneWidget);
  });

  testWidgets('offline submission confirms a local save, not a send', (
    tester,
  ) async {
    final savedAt = DateTime(2026, 9, 19, 12, 30);
    var smsComposerWasOpened = false;
    await pumpPhoneScreen(
      tester,
      SubmittingReportScreen(
        draft: completeDraft,
        flowMode: ReportFlowMode.offline,
        saveOfflineReport: (draft) async => SavedOfflineReport(
          id: 'LOCAL-00001',
          savedAt: savedAt,
          draft: draft,
        ),
        openSmsComposer: (report) async {
          smsComposerWasOpened = true;
          return true;
        },
      ),
    );
    expect(find.text('Saving report and preparing SMS…'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(smsComposerWasOpened, isTrue);
    expect(find.text('REPORT SAVED'), findsOneWidget);
    expect(find.text('LOCAL-00001'), findsOneWidget);
    expect(find.text('REPORT SENT'), findsNothing);
  });

  test('offline reports persist on the device', () async {
    const store = OfflineReportStore();
    final saved = await store.save(completeDraft);
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, saved.id);
    expect(loaded.single.draft.coordinates, completeDraft.coordinates);
    expect(loaded.single.draft.description, completeDraft.description);
  });

  test('SMS handoff addresses MDRRMO and prefills the full report', () async {
    Uri? openedUri;
    final handoff = OfflineSmsHandoff(
      launcher: (uri) async {
        openedUri = uri;
        return true;
      },
    );
    final report = SavedOfflineReport(
      id: 'LOCAL-00001',
      savedAt: DateTime(2026, 9, 19, 12, 30),
      draft: completeDraft,
      signedMessage: 'RSP1.synthetic.encoded.signature',
      smsRecipient: '+639000000001',
    );

    expect(await handoff.openComposer(report), isTrue);
    expect(openedUri?.scheme, 'sms');
    expect(openedUri?.path, '+639000000001');
    final message = openedUri?.queryParameters['body'];
    expect(message, report.signedMessage);
  });

  test('legacy unsigned SMS is never sent to the signed gateway', () {
    final handoff = OfflineSmsHandoff();
    final report = SavedOfflineReport(
      id: 'LOCAL-00001',
      savedAt: DateTime(2026, 9, 19, 12, 30),
      draft: completeDraft,
    );

    expect(() => handoff.buildMessage(report), throwsException);
  });

  test('SMS URI preserves the signed bytes without localization', () async {
    for (final body in ['RSP1.a.b.c', 'RSP1.d.e.f']) {
      Uri? openedUri;
      final handoff = OfflineSmsHandoff(
        launcher: (uri) async {
          openedUri = uri;
          return true;
        },
      );
      final report = SavedOfflineReport(
        id: 'LOCAL-00001',
        savedAt: DateTime(2026, 9, 19, 12, 30),
        draft: completeDraft,
        signedMessage: body,
        smsRecipient: '+639000000001',
      );

      expect(await handoff.openComposer(report), isTrue);
      expect(openedUri?.scheme, 'sms');
      expect(openedUri?.path, '+639000000001');
      expect(openedUri?.queryParameters['body'], body);
    }
  });
}

Color? _gpsCardColor(WidgetTester tester) {
  final card = tester.widget<Container>(
    find.byKey(const Key('report_gps_location_card')),
  );
  return (card.decoration as BoxDecoration).color;
}
