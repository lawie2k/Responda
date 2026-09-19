import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:responda/features/reporting/domain/models/incident_type.dart';
import 'package:responda/features/reporting/domain/models/report_draft.dart';
import 'package:responda/screens/shared/reporting/add_photo_screen.dart';
import 'package:responda/screens/shared/reporting/incident_location_screen.dart';
import 'package:responda/screens/shared/reporting/report_details_screen.dart';
import 'package:responda/screens/shared/reporting/review_report_screen.dart';

void main() {
  const draft = ReportDraft(
    incidentType: IncidentType.drowning,
    latitude: 7.135421,
    longitude: 125.912300,
    locationAccuracy: 8,
    landmark: 'Old landmark',
    description: 'Original description',
    morePeople: true,
    additionalAssistance: false,
    stillDangerous: true,
  );

  Future<void> pumpReview(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: ReviewReportScreen(draft: draft)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('review pencils are interactive edit buttons', (tester) async {
    await pumpReview(tester);

    for (final key in const [
      'review_edit_location',
      'review_edit_description',
      'review_edit_more_people',
      'review_edit_assistance',
      'review_edit_danger',
      'review_edit_photo',
    ]) {
      expect(
        find.byKey(ValueKey<String>(key)),
        findsOneWidget,
        reason: '$key should be available',
      );
    }
  });

  testWidgets('editing details returns the updated draft to review', (
    tester,
  ) async {
    await pumpReview(tester);

    await tester.tap(find.byKey(const Key('review_edit_description')));
    await tester.pumpAndSettle();
    expect(find.byType(ReportDetailsScreen), findsOneWidget);

    final description = find.byType(TextField);
    expect(
      tester.widget<TextField>(description).controller?.text,
      'Original description',
    );
    await tester.enterText(description, 'Updated rescue details');
    final continueButton = find.widgetWithText(FilledButton, 'Continue');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    expect(find.byType(ReviewReportScreen), findsOneWidget);
    expect(find.text('Updated rescue details'), findsOneWidget);
    expect(find.text('Original description'), findsNothing);
  });

  testWidgets('location and photo pencils open their original screens', (
    tester,
  ) async {
    await pumpReview(tester);

    await tester.tap(find.byKey(const Key('review_edit_location')));
    await tester.pumpAndSettle();
    expect(find.byType(IncidentLocationScreen), findsOneWidget);
    expect(find.text('Old landmark'), findsOneWidget);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('review_edit_photo')));
    await tester.tap(find.byKey(const Key('review_edit_photo')));
    await tester.pumpAndSettle();
    expect(find.byType(AddPhotoScreen), findsOneWidget);
  });
}
