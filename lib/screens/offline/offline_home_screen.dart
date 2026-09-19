import 'package:flutter/material.dart';

import 'package:responda/features/reporting/domain/models/report_flow_mode.dart';
import 'package:responda/screens/online/home_screen.dart';

class OfflineHomeScreen extends StatelessWidget {
  const OfflineHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const HomeScreen(flowMode: ReportFlowMode.offline);
  }
}
