enum GpsAccuracyQuality {
  acceptable,
  okay,
  notGood;

  static GpsAccuracyQuality fromMeters(double accuracy) {
    if (accuracy < 50) {
      return GpsAccuracyQuality.acceptable;
    }
    if (accuracy < 200) {
      return GpsAccuracyQuality.okay;
    }
    return GpsAccuracyQuality.notGood;
  }

  String get label => switch (this) {
    GpsAccuracyQuality.acceptable => 'ACCEPTABLE',
    GpsAccuracyQuality.okay => 'OKAY',
    GpsAccuracyQuality.notGood => 'NOT GOOD',
  };
}
