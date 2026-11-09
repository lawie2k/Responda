import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/core/widgets/responda_ios_tab_bar.dart';

void main() {
  testWidgets(
    'UIKit owns selection, Call leaves the page intact, and popups hide the bar',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final messenger = tester.binding.defaultBinaryMessenger;
      final updates = <Map<Object?, Object?>>[];
      Map<Object?, Object?>? creation;
      MethodChannel? native;
      final page = ValueNotifier(1);
      var calls = 0;
      const codec = StandardMethodCodec();
      const labels = ['Home', 'My Reports', '', 'Info', 'Settings'];
      final navigator = GlobalKey<NavigatorState>();

      messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
        call,
      ) async {
        if (call.method == 'create') {
          final args = call.arguments as Map;
          expect(args['viewType'], 'responda/native-tab-bar');
          final params = args['params'] as Uint8List;
          creation = const StandardMessageCodec().decodeMessage(
            ByteData.sublistView(params),
          ) as Map<Object?, Object?>;
          native = MethodChannel('responda/native-tab-bar/${args['id']}');
          messenger.setMockMethodCallHandler(native!, (call) async {
            if (call.method == 'update') {
              updates.add(Map<Object?, Object?>.from(call.arguments as Map));
            }
            return null;
          });
        }
        return null;
      });

      Future<void> nativeEvent(String method, [Object? arguments]) {
        final complete = Completer<void>();
        tester.binding.channelBuffers.push(
          native!.name,
          codec.encodeMethodCall(MethodCall(method, arguments)),
          (_) => complete.complete(),
        );
        return complete.future;
      }

      try {
        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: navigator,
            home: Scaffold(
              bottomNavigationBar: ValueListenableBuilder<int>(
                valueListenable: page,
                builder: (context, value, _) => RespondaIosTabBar(
                  pageIndex: value,
                  labels: labels,
                  tint: const Color(0xFF7A1F2B),
                  callAccessibilityLabel: 'Call MDRRMO',
                  onPageSelected: (value) => page.value = value,
                  onCall: () => calls++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(creation!['pageIndex'], 1);
        expect(creation!['labels'], labels);
        expect(creation!['callAccessibilityLabel'], 'Call MDRRMO');
        expect(
          find.descendant(
            of: find.byType(RespondaIosTabBar),
            matching: find.byType(AnimatedPositioned),
          ),
          findsNothing,
        );

        await nativeEvent('onPageSelected', 3);
        await tester.pumpAndSettle();
        expect(page.value, 3);
        expect(updates.last['pageIndex'], 3);
        final updateCount = updates.length;
        page.notifyListeners();
        await tester.pumpAndSettle();
        expect(updates.length, updateCount);
        await nativeEvent('onCall');
        await tester.pumpAndSettle();
        expect(calls, 1);
        expect(page.value, 3);
        await nativeEvent('onPageSelected', 4);
        expect(page.value, 3);

        unawaited(
          showDialog<void>(
            context: navigator.currentContext!,
            builder: (_) => const AlertDialog(content: Text('Warning')),
          ),
        );
        await tester.pumpAndSettle();
        expect(updates.last['visible'], isFalse);
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(updates.last['visible'], isTrue);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
        if (native != null) messenger.setMockMethodCallHandler(native!, null);
        page.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
