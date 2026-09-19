import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/core/location/device_location_service.dart';
import 'package:responda/core/location/gps_preference_controller.dart';
import 'package:responda/core/location/gps_preference_scope.dart';
import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/screens/online/main_shell.dart';
import 'package:responda/screens/shared/reporting/incident_location_screen.dart';

void main() {
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
      find.text('GPS is off in RESPONDA. Tap to allow GPS.'),
      findsOneWidget,
    );
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
          ),
        ),
      ),
    );
    await tester.pump();

    expect(locationRequests, 0);
    expect(find.text('Allow GPS'), findsNWidgets(3));
    expect(find.text('Allow GPS to show the map'), findsOneWidget);
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
  Future<bool?> readAllowGps() async => allowGps;

  @override
  Future<void> writeAllowGps(bool value) async {
    allowGps = value;
  }
}
