import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/core/navigation/app_routes.dart';
import 'package:responda/core/settings/app_settings_controller.dart';
import 'package:responda/core/settings/app_settings_scope.dart';
import 'package:responda/features/reporting/data/offline_report_store.dart';
import 'package:responda/features/reporting/data/online_report_store.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/features/tutorial/data/home_tutorial_store.dart';
import 'package:responda/screens/online/settings_screen.dart';

void main() {
  const report = ReportDraft(
    incidentType: IncidentType.accident,
    latitude: 7.135421,
    longitude: 125.912300,
    description: 'A person needs help.',
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    AppSettingsController? controller,
    GpsPreferenceController? gpsController,
    DeviceLocationService locationService = const DeviceLocationService(),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final screen = MaterialApp(
      home: Scaffold(body: SettingsScreen(locationService: locationService)),
    );
    final settings = gpsController == null
        ? screen
        : GpsPreferenceScope(controller: gpsController, child: screen);
    await tester.pumpWidget(
      controller == null
          ? settings
          : AppSettingsScope(controller: controller, child: settings),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('notification preference is saved through its controller', (
    tester,
  ) async {
    final store = _MemorySettingsStore(false);
    final controller = AppSettingsController(store: store);
    await controller.load();
    await pumpSettings(tester, controller: controller);

    final notificationSwitch = find.byType(Switch).first;
    expect(tester.widget<Switch>(notificationSwitch).value, isFalse);

    await tester.tap(notificationSwitch);
    await tester.pumpAndSettle();

    expect(controller.notificationsEnabled, isTrue);
    expect(store.notificationsEnabled, isTrue);
  });

  testWidgets(
    'GPS switch stays off and opens phone settings when permission is denied',
    (tester) async {
      final gpsController = GpsPreferenceController(
        store: _MemoryGpsPreferenceStore(true),
      );
      await gpsController.load();
      final locationService = _FakeLocationService(permissionGranted: false);

      await pumpSettings(
        tester,
        gpsController: gpsController,
        locationService: locationService,
      );

      final gpsTile = find.byKey(const Key('gps_settings_switch_tile'));
      final gpsSwitch = find.descendant(
        of: gpsTile,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(gpsSwitch).value, isFalse);
      expect(gpsController.allowGps, isFalse);

      await tester.tap(gpsSwitch);
      await tester.pump();

      expect(locationService.openSettingsCalls, 1);
      expect(tester.widget<Switch>(gpsSwitch).value, isFalse);

      locationService.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(gpsSwitch).value, isTrue);
      expect(gpsController.allowGps, isTrue);
    },
  );

  testWidgets(
    'GPS switch turns on when phone permission is granted while app is away',
    (tester) async {
      final gpsController = GpsPreferenceController(
        store: _MemoryGpsPreferenceStore(true),
      );
      await gpsController.load();
      final locationService = _FakeLocationService(permissionGranted: false);

      await pumpSettings(
        tester,
        gpsController: gpsController,
        locationService: locationService,
      );

      final gpsTile = find.byKey(const Key('gps_settings_switch_tile'));
      final gpsSwitch = find.descendant(
        of: gpsTile,
        matching: find.byType(Switch),
      );
      expect(tester.widget<Switch>(gpsSwitch).value, isFalse);
      expect(gpsController.allowGps, isFalse);

      locationService.permissionGranted = true;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(tester.widget<Switch>(gpsSwitch).value, isTrue);
      expect(gpsController.allowGps, isTrue);
    },
  );

  testWidgets('privacy tile opens local data information', (tester) async {
    await pumpSettings(tester);

    final tile = find.byKey(const Key('privacy_data_tile'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.text('On this device'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('testing option resets and reopens the Home tutorial', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final tutorialStore = _MemoryTutorialStore(true);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SettingsScreen(homeTutorialStore: tutorialStore)),
        routes: {
          AppRoutes.home: (_) => const Scaffold(body: Text('Tutorial home')),
        },
      ),
    );
    await tester.pumpAndSettle();

    final replayTile = find.byKey(const Key('replay_home_tutorial_tile'));
    await tester.ensureVisible(replayTile);
    await tester.tap(replayTile);
    await tester.pumpAndSettle();

    expect(tutorialStore.completed, isFalse);
    expect(find.text('Tutorial home'), findsOneWidget);
  });

  testWidgets('clear reports removes online and offline local records', (
    tester,
  ) async {
    const onlineStore = OnlineReportStore();
    const offlineStore = OfflineReportStore();
    await onlineStore.save(report);
    await offlineStore.save(report);
    await pumpSettings(tester);

    final tile = find.byKey(const Key('clear_local_reports_tile'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('confirm_clear_local_reports_button')),
    );
    await tester.pumpAndSettle();

    expect(await onlineStore.loadAll(), isEmpty);
    expect(await offlineStore.loadAll(), isEmpty);
    expect(find.text('Local reports cleared.'), findsOneWidget);
  });
}

class _MemoryGpsPreferenceStore implements GpsPreferenceStore {
  _MemoryGpsPreferenceStore(this.allowGps);

  bool? allowGps;

  @override
  Future<void> clearAllowGps() async => allowGps = null;

  @override
  Future<bool?> readAllowGps() async => allowGps;

  @override
  Future<void> writeAllowGps(bool value) async => allowGps = value;
}

class _MemoryTutorialStore implements HomeTutorialProgressStore {
  _MemoryTutorialStore(this.completed);

  bool completed;

  @override
  Future<bool> readCompleted() async => completed;

  @override
  Future<void> reset() async => completed = false;

  @override
  Future<void> writeCompleted(bool value) async => completed = value;
}

class _FakeLocationService extends DeviceLocationService {
  _FakeLocationService({required this.permissionGranted});

  bool permissionGranted;
  int openSettingsCalls = 0;

  @override
  Future<bool> hasWhenInUsePermission() async => permissionGranted;

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalls++;
    return true;
  }
}

class _MemorySettingsStore implements AppSettingsStore {
  _MemorySettingsStore(this.notificationsEnabled);

  bool? notificationsEnabled;

  @override
  Future<bool?> readNotificationsEnabled() async => notificationsEnabled;

  @override
  Future<void> writeNotificationsEnabled(bool value) async {
    notificationsEnabled = value;
  }
}
