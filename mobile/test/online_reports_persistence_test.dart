import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:responda/core/widgets/responda_bottom_navigation.dart';
import 'package:responda/core/network/responda_api_client.dart';
import 'package:responda/features/onboarding/data/account_controller.dart';
import 'package:responda/features/onboarding/domain/account_profile.dart';
import 'package:responda/features/onboarding/presentation/account_scope.dart';
import 'package:responda/features/reporting/data/online_report_store.dart';
import 'package:responda/features/reporting/data/mobile_report_api.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/screens/online/my_reports_screen.dart';
import 'package:responda/screens/online/main_shell.dart';
import 'package:responda/screens/shared/reporting/submitting_report_screen.dart';

import 'support/mobile_account_fakes.dart';

class _MemoryAccountStore implements AccountStore {
  AccountProfile? profile;
  @override
  Future<AccountProfile?> read() async => profile;
  @override
  Future<void> write(AccountProfile value) async {
    profile = value;
  }

  @override
  Future<void> clear() async {
    profile = null;
  }
}

class _TrackingApi extends FakeMobileAccountApi {
  final items = <Map<String, dynamic>>[];
  final reads = <String>[];
  bool fail = false;
  Completer<void>? gate;

  @override
  Future<Map<String, dynamic>> readReports({
    required String token,
    String? reportId,
    bool completed = false,
    int page = 1,
  }) async {
    reads.add(reportId ?? (completed ? 'completed' : 'active'));
    await gate?.future;
    if (fail) {
      throw const RespondaApiException('Server unavailable', statusCode: 503);
    }
    if (reportId != null) {
      return items.singleWhere((item) => item['report_id'] == reportId);
    }
    final matches = items
        .where(
          (item) =>
              ['resolved', 'closed'].contains(item['tracking_status']) ==
              completed,
        )
        .toList();
    return {
      'items': matches,
      'total': matches.length,
      'page': page,
      'total_pages': matches.isEmpty ? 0 : 1,
      'active_count': items
          .where(
            (item) => !['resolved', 'closed'].contains(item['tracking_status']),
          )
          .length,
    };
  }
}

Map<String, dynamic> _serverReport(
  String id, {
  String status = 'for_verification',
}) => {
  'report_id': id,
  'incident_type_code': 'fire',
  'description': 'Synthetic report.',
  'landmark': 'Synthetic landmark',
  'received_at': '2026-10-21T01:00:00Z',
  'updated_at': '2026-10-21T01:05:00Z',
  'tracking_status': status,
  'milestones': {
    'received': '2026-10-21T01:00:00Z',
    'for_verification': '2026-10-21T01:00:00Z',
  },
};

void main() {
  late _TrackingApi api;
  late AccountController account;
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    api = _TrackingApi();
    account = AccountController(
      store: _MemoryAccountStore(),
      api: api,
      tokenStore: MemoryTokenStore()..token = 'mobile_synthetic_token',
    );
    await account.load();
    addTearDown(account.dispose);
  });

  Future<void> pumpPhoneScreen(
    WidgetTester tester,
    Widget screen, {
    bool settle = true,
    bool withAccount = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final app = MaterialApp(home: Material(child: screen));
    await tester.pumpWidget(
      withAccount ? AccountScope(controller: account, child: app) : app,
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
    });
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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

  testWidgets(
    'an account report opens its real status journey without local history',
    (tester) async {
      const id = '00000000-0000-4000-8000-000000000001';
      api.items.add(_serverReport(id));

      await pumpPhoneScreen(tester, const MyReportsScreen());
      expect(find.text('1 ACTIVE'), findsOneWidget);
      expect(find.text(id), findsOneWidget);
      expect(find.text('View report status'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('report_action_$id')));
      await tester.pumpAndSettle();

      expect(find.text('Report Status'), findsOneWidget);
      expect(find.text('Report received safely'), findsOneWidget);
      expect(find.text('2 OF 7 STAGES'), findsOneWidget);
      expect(find.text('For verification'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('report_status_back_button'))),
        const Size(34, 34),
      );
    },
  );

  testWidgets('report status keeps the existing bottom navigation in place', (
    tester,
  ) async {
    const id = '00000000-0000-4000-8000-000000000002';
    api.items.add(_serverReport(id));

    await pumpPhoneScreen(
      tester,
      const MainShell(initialItem: RespondaNavItem.reports),
      settle: false,
    );
    final navigation = find.byType(RespondaBottomNavigation);
    final originalNavigationElement = tester.element(navigation);

    await tester.tap(find.byKey(const ValueKey('report_action_$id')));
    await tester.pump();

    expect(find.text('Report Status'), findsOneWidget);
    expect(navigation, findsOneWidget);
    expect(tester.element(navigation), same(originalNavigationElement));

    await tester.tap(find.byKey(const Key('report_status_back_button')));
    await tester.pump();
    expect(find.text('Track reports from your account'), findsOneWidget);
    expect(tester.element(navigation), same(originalNavigationElement));
  });

  testWidgets(
    'polling updates an open report, preserves navbar, and moves resolution to Completed',
    (tester) async {
      const id = '00000000-0000-4000-8000-000000000005';
      api.items.add(_serverReport(id));
      await pumpPhoneScreen(
        tester,
        const MainShell(initialItem: RespondaNavItem.reports),
        settle: false,
      );
      final navbar = tester.element(find.byType(RespondaBottomNavigation));
      await tester.tap(find.byKey(const ValueKey('report_action_$id')));
      await pumpFrames(tester);
      api.items[0] = _serverReport(id, status: 'responding');
      await tester.pump(const Duration(seconds: 5));
      await pumpFrames(tester);
      expect(find.text('The response team is responding'), findsOneWidget);
      expect(find.text('6 OF 7 STAGES'), findsOneWidget);
      expect(find.text('On site'), findsNothing);
      api.items[0] = _serverReport(id, status: 'resolved');
      await tester.pump(const Duration(seconds: 5));
      await pumpFrames(tester);
      expect(find.text('The incident has been resolved'), findsOneWidget);
      expect(
        tester.element(find.byType(RespondaBottomNavigation)),
        same(navbar),
      );
      await tester.tap(find.byKey(const Key('report_status_back_button')));
      await pumpFrames(tester);
      expect(find.text('0 ACTIVE'), findsOneWidget);
      await tester.tap(find.text('Completed'));
      await pumpFrames(tester);
      expect(find.text('RESOLVED'), findsOneWidget);
      expect(find.text(id), findsOneWidget);
    },
  );

  testWidgets(
    'tracking keeps last data on failure and refreshes after resume',
    (tester) async {
      const id = '00000000-0000-4000-8000-000000000006';
      api.items.add(_serverReport(id));
      await pumpPhoneScreen(tester, const MyReportsScreen());
      api.fail = true;
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text(id), findsOneWidget);
      expect(
        find.text('Could not refresh. Showing the last received update.'),
        findsOneWidget,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final calls = api.reads.length;
      await tester.pump(const Duration(seconds: 10));
      expect(api.reads.length, calls);
      api.fail = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(api.reads.length, greaterThan(calls));
      expect(
        find.text('Could not refresh. Showing the last received update.'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'local online receipts are never shown without account authorization',
    (tester) async {
      await const OnlineReportStore().save(
        draft,
        reportId: 'private-local-receipt',
      );
      await account.clearLocalSession();
      await pumpPhoneScreen(tester, const MyReportsScreen());
      expect(find.text('private-local-receipt'), findsNothing);
      expect(find.text('Sign in to track your reports.'), findsOneWidget);
    },
  );

  testWidgets(
    'polling pauses when another tab is active and does not overlap reads',
    (tester) async {
      await pumpPhoneScreen(
        tester,
        const MainShell(initialItem: RespondaNavItem.reports),
        settle: false,
      );
      api.gate = Completer<void>();
      await tester.pump(const Duration(seconds: 5));
      final calls = api.reads.length;
      await tester.pump(const Duration(seconds: 10));
      expect(api.reads.length, calls);
      api.gate!.complete();
      api.gate = null;
      await pumpFrames(tester);
      await tester.tap(find.text('Home'));
      await pumpFrames(tester);
      final hiddenCalls = api.reads.length;
      await tester.pump(const Duration(seconds: 10));
      expect(api.reads.length, hiddenCalls);
    },
  );

  testWidgets('online submission saves the report before success', (
    tester,
  ) async {
    var saved = false;
    final submittedAt = DateTime(2026, 9, 19, 9, 41);
    await pumpPhoneScreen(
      tester,
      SubmittingReportScreen(
        draft: draft,
        submitReport: (_, _) async => MobileReportReceipt(
          reportId: '00000000-0000-4000-8000-000000000003',
          receivedAt: submittedAt,
        ),
        saveOnlineReport:
            (submittedDraft, {required reportId, required submittedAt}) async {
              saved = true;
              return SavedOnlineReport(
                id: reportId,
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
    expect(find.text('00000000-0000-4000-8000-000000000003'), findsOneWidget);
  });

  testWidgets(
    'online submission without an authenticated account never shows success',
    (tester) async {
      await pumpPhoneScreen(
        tester,
        const SubmittingReportScreen(draft: draft),
        withAccount: false,
      );

      expect(
        find.text(
          'Sign in to your Responda account before submitting an online report.',
        ),
        findsOneWidget,
      );
      expect(find.text('REPORT SENT'), findsNothing);
      expect(find.text('Retry submission'), findsOneWidget);
    },
  );

  test('online reports persist as structured local records', () async {
    const store = OnlineReportStore();
    final saved = await store.save(
      draft,
      reportId: '00000000-0000-4000-8000-000000000004',
      submittedAt: DateTime(2026, 9, 19, 9, 41),
    );
    final loaded = await store.loadAll();

    expect(loaded, hasLength(1));
    expect(loaded.single.id, saved.id);
    expect(loaded.single.status, OnlineReportStatus.forVerification);
    expect(loaded.single.draft.description, draft.description);
  });
}
