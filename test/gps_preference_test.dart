import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/location/gps_accuracy_quality.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/screens/online/home_screen.dart';
import 'package:responda/screens/online/main_shell.dart';
import 'package:responda/screens/shared/reporting/incident_location_screen.dart';

void main() {
  test('GPS accuracy quality uses the safety thresholds', () {
    expect(GpsAccuracyQuality.fromMeters(49.9), GpsAccuracyQuality.acceptable);
    expect(GpsAccuracyQuality.fromMeters(50), GpsAccuracyQuality.okay);
    expect(GpsAccuracyQuality.fromMeters(199.9), GpsAccuracyQuality.okay);
    expect(GpsAccuracyQuality.fromMeters(200), GpsAccuracyQuality.notGood);
    expect(GpsAccuracyQuality.fromMeters(3000), GpsAccuracyQuality.notGood);
  });

  test('allows longer satellite-only GPS acquisition while offline', () {
    expect(
      DeviceLocationService.assistedFixTimeout,
      const Duration(seconds: 30),
    );
    expect(
      DeviceLocationService.satelliteFixTimeout,
      const Duration(seconds: 90),
    );
  });

  test('loads and saves the Allow GPS preference', () async {
    final store = _MemoryGpsPreferenceStore(false);
    final controller = GpsPreferenceController(store: store);

    await controller.load();
    expect(controller.allowGps, isFalse);

    await controller.setAllowGps(true);
    expect(store.allowGps, isTrue);

    final restartedController = GpsPreferenceController(store: store);
    await restartedController.load();
    expect(restartedController.allowGps, isTrue);

    await restartedController.setAllowGps(false);
    await restartedController.resetPreference();
    expect(restartedController.allowGps, isTrue);
    expect(store.allowGps, isNull);
  });

  testWidgets('home shows Allow GPS without requesting a location when off', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final controller = GpsPreferenceController(
      store: _MemoryGpsPreferenceStore(false),
    );
    await controller.load();

    await tester.pumpWidget(
      GpsPreferenceScope(
        controller: controller,
        child: const MaterialApp(home: MainShell()),
      ),
    );
    await tester.pump();

    expect(find.text('Allow GPS'), findsOneWidget);
    expect(
      find.text('GPS is off in RESPONDA. Tap to open Settings.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('home_gps_card')));
    await tester.pump();

    expect(controller.allowGps, isFalse);
    expect(find.byKey(const Key('language_settings_tile')), findsOneWidget);
  });

  testWidgets('incident location does not call its GPS loader when off', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final controller = GpsPreferenceController(
      store: _MemoryGpsPreferenceStore(false),
    );
    await controller.load();
    var locationRequests = 0;
    var settingsOpened = false;

    await tester.pumpWidget(
      GpsPreferenceScope(
        controller: controller,
        child: MaterialApp(
          home: IncidentLocationScreen(
            draft: const ReportDraft(incidentType: IncidentType.accident),
            loadLocation: () async {
              locationRequests++;
              return DeviceLocationData(
                latitude: 7.135421,
                longitude: 125.912300,
                accuracy: 8,
                timestamp: DateTime(2026, 9, 19),
              );
            },
            onOpenSettings: () => settingsOpened = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(locationRequests, 0);
    expect(find.text('Allow GPS'), findsNWidgets(2));
    expect(find.text('Allow GPS to show the map'), findsOneWidget);

    await tester.tap(find.byKey(const Key('report_open_settings_button')));
    await tester.pump();

    expect(settingsOpened, isTrue);
    expect(controller.allowGps, isFalse);
    expect(locationRequests, 0);
  });

  testWidgets('home refreshes GPS on resume and every five minutes', (
    tester,
  ) async {
    await _setPhoneSize(tester);
    final controller = GpsPreferenceController(
      store: _MemoryGpsPreferenceStore(true),
    );
    await controller.load();
    var locationRequests = 0;

    await tester.pumpWidget(
      GpsPreferenceScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(
            body: HomeGpsLocationCard(
              locationLoader: () async {
                locationRequests++;
                return DeviceLocationData(
                  latitude: 7.135421 + locationRequests,
                  longitude: 125.912300,
                  accuracy: 8,
                  timestamp: DateTime(2026, 9, 21),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(locationRequests, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(locationRequests, 2);

    await tester.pump(const Duration(minutes: 5));
    await tester.pump();
    expect(locationRequests, 3);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('home GPS card shows its color-coded accuracy badge', (
    tester,
  ) async {
    await _setPhoneSize(tester);

    for (final testCase in const [
      (20.0, GpsAccuracyQuality.acceptable),
      (120.0, GpsAccuracyQuality.okay),
      (3000.0, GpsAccuracyQuality.notGood),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeGpsLocationCard(
              key: ValueKey(testCase.$1),
              locationLoader: () async => DeviceLocationData(
                latitude: 7.129329,
                longitude: 125.898422,
                accuracy: testCase.$1,
                timestamp: DateTime(2026, 9, 24),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(Key('home_gps_accuracy_${testCase.$2.name}')),
        findsOneWidget,
      );
      expect(find.text(testCase.$2.label), findsOneWidget);
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _setPhoneSize(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

class _MemoryGpsPreferenceStore implements GpsPreferenceStore {
  _MemoryGpsPreferenceStore(this.allowGps);

  bool? allowGps;

  @override
  Future<void> clearAllowGps() async {
    allowGps = null;
  }

  @override
  Future<bool?> readAllowGps() async => allowGps;

  @override
  Future<void> writeAllowGps(bool value) async {
    allowGps = value;
  }
}
