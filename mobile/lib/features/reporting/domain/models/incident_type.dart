enum IncidentType {
  accident(label: 'Road Accident', apiValue: 'road_accident'),
  flood(label: 'Flood', apiValue: 'flood'),
  fire(label: 'Fire', apiValue: 'fire'),
  drowning(label: 'Drowning', apiValue: 'drowning'),
  other(label: 'Other Disaster-Related Incident', apiValue: 'other');

  const IncidentType({required this.label, required this.apiValue});

  final String label;
  final String apiValue;
}
