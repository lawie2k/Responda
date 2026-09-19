import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responda/app.dart';

void main() {
  testWidgets('shows the RESPONDA app shell', (tester) async {
    await tester.pumpWidget(const RespondaApp());

    expect(find.text('RESPONDA'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
