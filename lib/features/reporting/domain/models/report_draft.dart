import 'incident_type.dart';

class ReportDraft {
  const ReportDraft({
    required this.incidentType,
    this.latitude,
    this.longitude,
    this.locationAccuracy,
    this.locationCapturedAt,
    this.landmark = '',
    this.description = '',
    this.morePeople,
    this.additionalAssistance,
    this.stillDangerous,
    this.photoPath,
  });

  final IncidentType incidentType;
  final double? latitude;
  final double? longitude;
  final double? locationAccuracy;
  final DateTime? locationCapturedAt;
  final String landmark;
  final String description;
  final bool? morePeople;
  final bool? additionalAssistance;
  final bool? stillDangerous;
  final String? photoPath;

  bool get hasLocation => latitude != null && longitude != null;

  String get coordinates {
    if (!hasLocation) {
      return 'Location not captured';
    }
    return '${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}';
  }

  String get accuracyLabel => locationAccuracy == null
      ? 'Accuracy unavailable'
      : '±${locationAccuracy!.round()} m accuracy';

  String get locationTitle =>
      landmark.trim().isEmpty ? 'Current GPS location' : landmark.trim();

  Map<String, Object?> toJson() => {
    'incidentType': incidentType.apiValue,
    'latitude': latitude,
    'longitude': longitude,
    'locationAccuracy': locationAccuracy,
    'locationCapturedAt': locationCapturedAt?.toIso8601String(),
    'landmark': landmark,
    'description': description,
    'morePeople': morePeople,
    'additionalAssistance': additionalAssistance,
    'stillDangerous': stillDangerous,
    'photoPath': photoPath,
  };

  factory ReportDraft.fromJson(Map<String, Object?> json) {
    final incidentValue = json['incidentType'] as String?;
    return ReportDraft(
      incidentType: IncidentType.values.firstWhere(
        (type) => type.apiValue == incidentValue,
        orElse: () => IncidentType.other,
      ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationAccuracy: (json['locationAccuracy'] as num?)?.toDouble(),
      locationCapturedAt: DateTime.tryParse(
        json['locationCapturedAt'] as String? ?? '',
      ),
      landmark: json['landmark'] as String? ?? '',
      description: json['description'] as String? ?? '',
      morePeople: json['morePeople'] as bool?,
      additionalAssistance: json['additionalAssistance'] as bool?,
      stillDangerous: json['stillDangerous'] as bool?,
      photoPath: json['photoPath'] as String?,
    );
  }

  ReportDraft copyWith({
    double? latitude,
    double? longitude,
    double? locationAccuracy,
    DateTime? locationCapturedAt,
    String? landmark,
    String? description,
    bool? morePeople,
    bool? additionalAssistance,
    bool? stillDangerous,
    String? photoPath,
  }) {
    return ReportDraft(
      incidentType: incidentType,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationAccuracy: locationAccuracy ?? this.locationAccuracy,
      locationCapturedAt: locationCapturedAt ?? this.locationCapturedAt,
      landmark: landmark ?? this.landmark,
      description: description ?? this.description,
      morePeople: morePeople ?? this.morePeople,
      additionalAssistance: additionalAssistance ?? this.additionalAssistance,
      stillDangerous: stillDangerous ?? this.stillDangerous,
      photoPath: photoPath ?? this.photoPath,
    );
  }
}
