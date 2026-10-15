enum ReportFlowMode { online, offline }

extension ReportFlowModeX on ReportFlowMode {
  bool get isOffline => this == ReportFlowMode.offline;

  int get totalFormSteps => isOffline ? 4 : 5;
}
