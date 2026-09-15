class AppConstants {
  AppConstants._();

  static const String appName = 'TOSUMO';
  static const String appVersion = 'v2.1.0';
  static const String tagline = 'Votre identité médicale numérique.';
  static const String lsPrefix = 'medicard_mock_';

  static const List<String> bloodTypes = [
    'O+', 'A+', 'B+', 'AB+', 'O-', 'A-', 'B-', 'AB-',
  ];

  static const List<String> allergiesList = [
    'Penicillin', 'Peanuts', 'Ibuprofen', 'Sulfa', 'Aspirin',
    'Codeine', 'Latex', 'Dust Mites', 'Shellfish',
  ];

  static const List<String> chronicConditions = [
    'Mild Hypertension', 'Seasonal Asthma', 'Type 2 Diabetes',
    'High Cholesterol', 'GERD', 'Hypothyroidism', 'Migraine',
  ];
}
