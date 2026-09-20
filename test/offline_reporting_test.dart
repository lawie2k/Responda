import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:responda/core/localization/app_language.dart';
import 'package:responda/core/localization/app_strings.dart';
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

  testWidgets('offline home uses the Figma offline status treatment', (
    tester,
  ) async {
    await pumpPhoneScreen(tester, const OfflineMainShell());
    expect(find.text('Offline'), findsOneWidget);
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
    expect(find.text('Landmark'), findsNothing);
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
    );

    expect(await handoff.openComposer(report), isTrue);
    expect(openedUri?.scheme, 'sms');
    expect(openedUri?.path, '09476236516');
    final message = openedUri?.queryParameters['body'];
    expect(message, contains('RESPONDA EMERGENCY REPORT'));
    expect(message, contains('Incident: Road Accident'));
    expect(message, contains('GPS: 7.135421, 125.912300'));
    expect(message, contains('Details: A person needs help.'));
    expect(message, contains('Time: 2026-09-19T12:30:00.000'));
  });

  test('SMS handoff uses the selected Bisaya language', () {
    final handoff = OfflineSmsHandoff(
      strings: const AppStrings(AppLanguage.cebuano),
    );
    final report = SavedOfflineReport(
      id: 'LOCAL-00001',
      savedAt: DateTime(2026, 9, 19, 12, 30),
      draft: completeDraft,
    );

    final message = handoff.buildMessage(report);
    expect(message, contains('Insidente: Aksidente sa Dalan'));
    expect(message, contains('Oras: 2026-09-19T12:30:00.000'));
    expect(message, contains('Dugang nga tabang: Dili'));
  });

  test('Tagalog and Bisaya SMS handoffs open a valid Messages URI', () async {
    for (final testCase in const [
      (AppLanguage.filipino, 'Insidente: Aksidente sa Kalsada'),
      (AppLanguage.cebuano, 'Insidente: Aksidente sa Dalan'),
    ]) {
      Uri? openedUri;
      final handoff = OfflineSmsHandoff(
        strings: AppStrings(testCase.$1),
        launcher: (uri) async {
          openedUri = uri;
          return true;
        },
      );
      final report = SavedOfflineReport(
        id: 'LOCAL-00001',
        savedAt: DateTime(2026, 9, 19, 12, 30),
        draft: completeDraft,
      );

      expect(await handoff.openComposer(report), isTrue);
      expect(openedUri?.scheme, 'sms');
      expect(openedUri?.path, OfflineSmsHandoff.recipient);
      expect(openedUri?.queryParameters['body'], contains(testCase.$2));
    }
  });
}
