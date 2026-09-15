import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../providers/core_providers.dart';
import '../../services/token_storage_service.dart';
import '../../services/api_client.dart';
import '../../database/sync_queue.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/doctor_repository.dart';
import '../../../domain/repositories/patient_repository.dart';
import '../../../domain/repositories/appointment_repository.dart';
import '../../../domain/repositories/consultation_repository.dart';
import '../../../domain/repositories/prescription_repository.dart';
import '../../../domain/repositories/laboratory_repository.dart';
import '../../../domain/repositories/imaging_repository.dart';
import '../../../domain/repositories/chat_repository.dart';
import '../../../domain/repositories/notification_repository.dart';
import '../../../domain/repositories/emergency_repository.dart';
import '../../../domain/repositories/analytics_repository.dart';
import '../../../domain/repositories/settings_repository.dart';
import 'local_doctor_repository.dart';
import 'remote_doctor_repository.dart';
import 'doctor_coordinator.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final tokenStorageServiceProvider = Provider<TokenStorageService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return TokenStorageService(storage);
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageServiceProvider);
  return ApiClient(tokenStorage: tokenStorage);
});

final syncQueueProvider = Provider<SyncQueue>((ref) => SyncQueue());

final localDoctorRepoProvider = Provider<LocalDoctorRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  final storage = ref.watch(secureStorageProvider);
  return LocalDoctorRepository(db, storage);
});

final remoteDoctorRepoProvider = Provider<RemoteDoctorRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  final storage = ref.watch(tokenStorageServiceProvider);
  return RemoteDoctorRepository(client, storage);
});

final coordinatorProvider = Provider<RepositoryCoordinator>((ref) {
  final coordinator = RepositoryCoordinator(
    ref.watch(localDoctorRepoProvider),
    ref.watch(remoteDoctorRepoProvider),
    ref.watch(syncQueueProvider),
  );
  ref.onDispose(() => coordinator.dispose());
  return coordinator;
});

final doctorRepositoryProvider = Provider<DoctorRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final appointmentRepositoryProvider = Provider<AppointmentRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final consultationRepositoryProvider = Provider<ConsultationRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final laboratoryRepositoryProvider = Provider<LaboratoryRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final imagingRepositoryProvider = Provider<ImagingRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return ref.watch(coordinatorProvider);
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return ref.watch(coordinatorProvider);
});
