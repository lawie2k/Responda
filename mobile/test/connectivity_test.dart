import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:responda/app.dart';
import 'package:responda/core/connectivity/connectivity_controller.dart';
import 'package:responda/core/connectivity/connectivity_gate.dart';
import 'package:responda/core/connectivity/connectivity_scope.dart';

class _FakeConnectivityReader implements ConnectivityReader {
  _FakeConnectivityReader(this.current);

  List<ConnectivityResult> current;
  int checkCount = 0;
  final changes = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    checkCount += 1;
    return current;
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => changes.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('connectivity gate switches between offline and online shells', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final reader = _FakeConnectivityReader([ConnectivityResult.none]);
    final controller = ConnectivityController(reader: reader);
    await controller.initialize();
    addTearDown(() async {
      controller.dispose();
      await reader.changes.close();
    });

    await tester.pumpWidget(
      ConnectivityScope(
        controller: controller,
        child: const MaterialApp(home: ConnectivityGate()),
      ),
    );
    await tester.pump();
    expect(find.text('Offline'), findsNothing);
    expect(find.text("You're Offline"), findsOneWidget);
    expect(find.byKey(const Key('offline_notice_sprite')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dismiss_offline_notice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("You're Offline"), findsNothing);

    reader.changes.add([ConnectivityResult.wifi]);
    await tester.pump();
    expect(find.text('Online'), findsNothing);
    expect(find.text('Offline'), findsNothing);

    reader.changes.add([ConnectivityResult.none]);
    await tester.pump();
    await tester.pump();
    expect(find.text("You're Offline"), findsOneWidget);
  });

  testWidgets('app checks connectivity again when it resumes', (tester) async {
    final reader = _FakeConnectivityReader([ConnectivityResult.wifi]);
    final controller = ConnectivityController(reader: reader);
    addTearDown(() async {
      controller.dispose();
      await reader.changes.close();
    });

    await tester.pumpWidget(RespondaApp(connectivityController: controller));
    await tester.pump();
    final checksAfterLaunch = reader.checkCount;
    expect(checksAfterLaunch, greaterThanOrEqualTo(1));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(reader.checkCount, checksAfterLaunch + 1);
  });

  test('configured backend health is required for online mode', () async {
    final reader = _FakeConnectivityReader([ConnectivityResult.wifi]);
    var backendAvailable = false;
    final controller = ConnectivityController(
      reader: reader,
      backendAvailabilityCheck: () async => backendAvailable,
    );
    addTearDown(() async {
      controller.dispose();
      await reader.changes.close();
    });

    await controller.initialize();
    expect(controller.isOffline, isTrue);

    backendAvailable = true;
    await controller.refresh();
    expect(controller.isOnline, isTrue);
  });

  test(
    'reachable wired backend works even when iOS reports no internet path',
    () async {
      final reader = _FakeConnectivityReader([ConnectivityResult.none]);
      var available = true;
      var healthChecks = 0;
      final controller = ConnectivityController(
        reader: reader,
        backendAvailabilityCheck: () async {
          healthChecks++;
          return available;
        },
      );
      addTearDown(() async {
        controller.dispose();
        await reader.changes.close();
      });
      await controller.initialize();
      expect(healthChecks, 1);
      expect(controller.isOnline, isTrue);
      available = false;
      await controller.refresh();
      expect(controller.isOffline, isTrue);
    },
  );

  test('older health result cannot override a newer failed check', () async {
    final reader = _FakeConnectivityReader([ConnectivityResult.wifi]);
    final oldCheck = Completer<bool>();
    var checks = 0;
    final controller = ConnectivityController(
      reader: reader,
      backendAvailabilityCheck: () =>
          ++checks == 1 ? oldCheck.future : Future.value(false),
    );
    addTearDown(() async {
      controller.dispose();
      await reader.changes.close();
    });
    final first = controller.initialize();
    await Future<void>.delayed(Duration.zero);
    reader.current = [ConnectivityResult.none];
    await controller.refresh();
    oldCheck.complete(true);
    await first;
    expect(controller.isOffline, isTrue);
  });

  testWidgets(
    'foreground retry discovers backend recovery without a network change',
    (tester) async {
      final reader = _FakeConnectivityReader([ConnectivityResult.wifi]);
      var available = false;
      final controller = ConnectivityController(
        reader: reader,
        backendAvailabilityCheck: () async => available,
      );
      addTearDown(() async {
        controller.dispose();
        await reader.changes.close();
      });
      await tester.pumpWidget(RespondaApp(connectivityController: controller));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(controller.isOffline, isTrue);
      available = true;
      await tester.pump(const Duration(seconds: 15));
      await tester.pump();
      expect(controller.isOnline, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
