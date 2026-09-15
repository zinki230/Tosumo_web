import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../network/api_providers.dart';

class AppointmentService {
  final ApiClient _client;

  AppointmentService(this._client);

  Future<Map<String, dynamic>> bookAppointment({
    required String doctorId,
    required String doctorName,
    required String specialty,
    required String location,
    required String date,
    String? notes,
  }) async {
    final response = await _client.post(ApiEndpoints.appointments, data: {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'specialty': specialty,
      'location': location,
      'date': date,
      'notes': notes,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> rescheduleAppointment({
    required String appointmentId,
    required String newDate,
    String? reason,
  }) async {
    await _client.patch(ApiEndpoints.appointmentReschedule(appointmentId), data: {
      'newDate': newDate,
      'reason': reason,
    });
  }

  Future<void> cancelAppointment({
    required String appointmentId,
    String? reason,
  }) async {
    await _client.patch(ApiEndpoints.appointmentCancel(appointmentId), data: {
      'reason': reason,
    });
  }

  Future<void> confirmAppointment(String appointmentId) async {
    await _client.patch(ApiEndpoints.appointmentApprove(appointmentId));
  }

  Future<List<Map<String, dynamic>>> getAppointments({
    String? patientId,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _client.get(
      ApiEndpoints.appointments,
      queryParameters: {
        'patientId': patientId,
        'status': status,
        'page': page,
        'limit': limit,
      },
    );
    return (response.data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getAppointment(String id) async {
    final response = await _client.get(ApiEndpoints.appointment(id));
    return response.data as Map<String, dynamic>;
  }
}

final appointmentServiceProvider = Provider<AppointmentService>((ref) {
  return AppointmentService(ref.read(apiClientProvider));
});
