abstract class AnalyticsRepository {
  Future<Map<String, dynamic>> getDoctorStats(
    String doctorId, {
    String? period,
  });
  Future<List<Map<String, dynamic>>> getDiagnosisDistribution(
    String doctorId,
  );
  Future<Map<String, dynamic>> getAppointmentCompletion(String doctorId);
  Future<List<Map<String, dynamic>>> getWeeklyTrends(String doctorId);
}
