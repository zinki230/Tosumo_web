import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../database/local_database.dart';
import '../../database/sync_queue.dart';
import '../../network/api_providers.dart';
import '../../domain/repositories/patient_repository.dart';
import 'local_patient_repository.dart';
import 'remote_patient_repository.dart';
import 'repository_coordinator.dart';

final syncQueueProvider = Provider<SyncQueue>((ref) => SyncQueue());

final localPatientRepositoryProvider = Provider<LocalPatientRepository>((ref) {
  return LocalPatientRepository(ref.read(localDatabaseProvider));
});

final remotePatientRepositoryProvider = Provider<RemotePatientRepository>((ref) {
  return RemotePatientRepository(ref.read(apiClientProvider));
});

final repositoryCoordinatorProvider = Provider<RepositoryCoordinator>((ref) {
  final coordinator = RepositoryCoordinator(
    ref.read(localPatientRepositoryProvider),
    ref.read(remotePatientRepositoryProvider),
    ref.read(syncQueueProvider),
  );
  ref.onDispose(() => coordinator.dispose());
  return coordinator;
});

final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return ref.read(repositoryCoordinatorProvider);
});
