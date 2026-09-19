import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:responda/features/reporting/data/online_report_store.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/screens/online/my_reports_screen.dart';
import 'package:responda/screens/shared/reporting/submitting_report_screen.dart';

void main() {
  const draft = ReportDraft(
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
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpPhoneScreen(WidgetTester tester, Widget screen) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: Material(child: screen)));
    await tester.pumpAndSettle();
  }

  testWidgets('My Reports starts empty without mock report cards', (
    tester,
  ) async {
    await pumpPhoneScreen(tester, const MyReportsScreen());

    expect(find.text('0 ACTIVE'), findsOneWidget);
    expect(find.text('No active reports'), findsOneWidget);
    expect(find.text('RSP-2026-00872'), findsNothing);
    expect(find.text('TEAM DISPATCHED'), findsNothing);
  });

  testWidgets('a stored online report opens its working status journey', (
    tester,
  ) async {
    const store = OnlineReportStore();
    final saved = await store.save(
      draft,
      submittedAt: DateTime(2026, 9, 19, 9, 41),
    );

    await pumpPhoneScreen(tester, const MyReportsScreen());
    expect(find.text('1 ACTIVE'), findsOneWidget);
    expect(find.text(saved.id), findsOneWidget);
    expect(find.text('View report status'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('report_action_${saved.id}')));
    await tester.pumpAndSettle();

    expect(find.text('Report Status'), findsOneWidget);
    expect(find.text('Report received safely'), findsOneWidget);
    expect(find.text('2 OF 7 STAGES'), findsOneWidget);
    expect(find.text('For verification'), findsOneWidget);
    expect(find.text('Resolved'), findsOneWidget);
  });

  testWidgets('online submission saves the report before success', (
    tester,
  ) async {
    var saved = false;
    final submittedAt = DateTime(2026, 9, 19, 9, 41);
    await pumpPhoneScreen(
      tester,
      SubmittingReportScreen(
        draft: draft,
        submitReport: (_) async {},
        saveOnlineReport: (submittedDraft) async {
          saved = true;
          return SavedOnlineReport(
            id: 'RSP-2026-00001',
            submittedAt: submittedAt,
            draft: submittedDraft,
          );
        },
      ),
    );

    expect(saved, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.text('REPORT SENT'), findsOneWidget);
    expect(find.text('RSP-2026-00001'), findsOneWidget);
  });

  test('online reports persist as structured local records', () async {
    const store = OnlineReportStore();
    final saved = await store.save(
      draft,
      submittedAt: DateTime(2026, 9, 19, 9, 41),
    );
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, saved.id);
    expect(loaded.single.status, OnlineReportStatus.forVerification);
    expect(loaded.single.draft.description, draft.description);
  });
}
