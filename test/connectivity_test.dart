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
    expect(find.text('Offline'), findsOneWidget);
    expect(find.text("You're Offline"), findsOneWidget);
    expect(find.byKey(const Key('offline_notice_sprite')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dismiss_offline_notice')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text("You're Offline"), findsNothing);

    reader.changes.add([ConnectivityResult.wifi]);
    await tester.pump();
    expect(find.text('Online'), findsOneWidget);
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
}
