import 'package:flutter/material.dart';

import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';
import 'package:responda/screens/online/home_screen.dart';

class OfflineHomeScreen extends StatelessWidget {
  const OfflineHomeScreen({
    this.onOpenSettings,
    this.tutorialReportButtonKey,
    this.tutorialQuickIncidentKey,
    this.tutorialGpsCardKey,
    super.key,
  });

  final VoidCallback? onOpenSettings;
  final GlobalKey? tutorialReportButtonKey;
  final GlobalKey? tutorialQuickIncidentKey;
  final GlobalKey? tutorialGpsCardKey;

  @override
  Widget build(BuildContext context) {
    return HomeScreen(
      flowMode: ReportFlowMode.offline,
      onOpenSettings: onOpenSettings,
      tutorialReportButtonKey: tutorialReportButtonKey,
      tutorialQuickIncidentKey: tutorialQuickIncidentKey,
      tutorialGpsCardKey: tutorialGpsCardKey,
    );
  }
}
