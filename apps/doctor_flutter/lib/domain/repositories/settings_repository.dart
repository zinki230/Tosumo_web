import '../models/working_hour.dart';

abstract class SettingsRepository {
  Future<void> updateLanguage(String language);
  Future<void> updateTheme(String theme);
  Future<void> updateNotificationPreferences(Map<String, dynamic> prefs);
  Future<void> updateWorkingHours(List<WorkingHour> hours);
  Future<void> updateAvailability(bool isAvailable);
  Future<void> setPinCode(String pin);
  Future<void> enableBiometric(bool enabled);
  Future<void> enableOfflineMode(bool enabled);
}
