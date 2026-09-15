import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../domain/repositories/patient_repository.dart';
import '../../database/sync_queue.dart';
import '../../../shared/models/patient.dart';
import '../../../shared/models/card_model.dart';
import '../../../shared/models/booklet_entry.dart';
import '../../../shared/models/access_grant.dart';
import '../../../shared/models/audit_event.dart';
import '../../../shared/models/health_journey_entry.dart';
import '../../../shared/models/doctor_profile.dart';
import '../../../shared/models/hospital_info.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../shared/models/notification_model.dart';
import 'local_patient_repository.dart';
import 'remote_patient_repository.dart';

class RepositoryCoordinator implements PatientRepository {
  final LocalPatientRepository _local;
  final RemotePatientRepository _remote;
  final SyncQueue _syncQueue;

  bool _online = true;
  final StreamController<bool> _onlineController = StreamController<bool>.broadcast();

  Stream<bool> get onlineStream => _onlineController.stream;
  bool get isOnline => _online;
  SyncQueue get syncQueue => _syncQueue;

  RepositoryCoordinator(this._local, this._remote, this._syncQueue);

  void setOnline(bool value) {
    _online = value;
    _onlineController.add(value);
  }

  Future<T> _fetchWithRemoteCache<T, L>({
    required Future<T> Function() remote,
    required Future<L> Function() local,
    required void Function(T) cacheLocally,
  }) async {
    T? remoteResult;
    try {
      remoteResult = await remote().timeout(const Duration(seconds: 12));
      if (!_online) setOnline(true);
    } catch (_) {
      remoteResult = null;
    }
    // The remote result is authoritative. A local cache write must NEVER break
    // the request: if Hive fails (corrupt box, unavailable storage, etc.) we log
    // and keep the fresh remote data so the UI still renders real backend data.
    if (remoteResult != null) {
      try {
        cacheLocally(remoteResult);
      } catch (e) {
        debugPrint('[CACHE] persist failed (ignored, using remote): $e');
      }
      return remoteResult;
    }
    final localResult = await local();
    return localResult as T;
  }

  void _enqueueSync(String endpoint, String type, Map<String, dynamic> body) {
    _syncQueue.enqueue(SyncOperation(
      id: '${DateTime.now().millisecondsSinceEpoch}_${endpoint.hashCode}',
      type: type,
      endpoint: endpoint,
      body: body,
    ));
  }

  @override
  Future<Patient?> getPatientProfile(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getPatientProfile(patientId),
      local: () => _local.getPatientProfile(patientId),
      cacheLocally: (Patient? p) { if (p != null) _local.savePatient(p); },
    );
  }

  @override
  Future<CardModel?> getCard(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getCard(patientId),
      local: () => _local.getCard(patientId),
      cacheLocally: (CardModel? c) { if (c != null) _local.saveCard(c); },
    );
  }

  @override
  Future<List<BookletEntry>> getMedicalBooklet(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getMedicalBooklet(patientId),
      local: () => _local.getMedicalBooklet(patientId),
      cacheLocally: (List<BookletEntry> e) => _local.saveMedicalBooklet(e),
    );
  }

  @override
  Future<List<AccessGrant>> getAccessGrants(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getAccessGrants(patientId),
      local: () => _local.getAccessGrants(patientId),
      cacheLocally: (List<AccessGrant> g) => _local.saveAccessGrants(g),
    );
  }

  @override
  Future<List<AuditEvent>> getAuditLog(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getAuditLog(patientId),
      local: () => _local.getAuditLog(patientId),
      cacheLocally: (_) {},
    );
  }

  @override
  Future<List<HealthJourneyEntry>> getHealthJourney(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getHealthJourney(patientId),
      local: () => _local.getHealthJourney(patientId),
      cacheLocally: (_) {},
    );
  }

  @override
  Future<List<DoctorProfile>> getDoctors() async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getDoctors(),
      local: () => _local.getDoctors(),
      cacheLocally: (List<DoctorProfile> d) => _local.saveDoctorList(d),
    );
  }

  @override
  Future<DoctorProfile?> getDoctorById(String doctorId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getDoctorById(doctorId),
      local: () => _local.getDoctorById(doctorId),
      cacheLocally: (DoctorProfile? d) { if (d != null) _local.saveDoctor(d); },
    );
  }

  @override
  Future<List<HospitalInfo>> getHospitals() async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getHospitals(),
      local: () => _local.getHospitals(),
      cacheLocally: (_) {},
    );
  }

  @override
  Future<List<ChatConversation>> getChats(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getChats(patientId),
      local: () => _local.getChats(patientId),
      cacheLocally: (List<ChatConversation> c) => _local.saveChatList(c),
    );
  }

  @override
  Future<ChatConversation?> getChatById(String chatId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getChatById(chatId),
      local: () => _local.getChatById(chatId),
      cacheLocally: (ChatConversation? c) { if (c != null) _local.saveChat(c); },
    );
  }

  @override
  Future<List<NotificationModel>> getNotifications(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getNotifications(patientId),
      local: () => _local.getNotifications(patientId),
      cacheLocally: (List<NotificationModel> n) => _local.saveNotifications(n),
    );
  }

  @override
  Future<List<NotificationModel>> getUnreadNotifications(String patientId) async {
    final all = await getNotifications(patientId);
    return all.where((n) => !n.read).toList();
  }

  @override
  Future<AccessGrant> approveAccessRequest(String grantId) async {
    if (_online) {
      try {
        return await _remote.approveAccessRequest(grantId);
      } catch (_) {
        setOnline(false);
      }
    }
    final result = await _local.approveAccessRequest(grantId);
    _enqueueSync('/api/v1/access/$grantId/approve', 'PATCH', {});
    return result;
  }

  @override
  Future<void> revokeAccess(String grantId) async {
    if (_online) {
      try {
        await _remote.revokeAccess(grantId);
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.revokeAccess(grantId);
    _enqueueSync('/api/v1/access/$grantId/revoke', 'PATCH', {});
  }

  @override
  Future<CardModel> requestCardReissue(String patientId) async {
    if (_online) {
      try {
        final result = await _remote.requestCardReissue(patientId);
        await _local.saveCard(result);
        return result;
      } catch (_) {
        setOnline(false);
      }
    }
    final result = await _local.requestCardReissue(patientId);
    _enqueueSync('/api/v1/cards/reissue', 'POST', {'patientId': patientId});
    return result;
  }

  @override
  Future<Patient> registerPatient({
    required String name,
    required String gender,
    required String dateOfBirth,
    required String city,
  }) async {
    if (_online) {
      try {
        final result = await _remote.registerPatient(name: name, gender: gender, dateOfBirth: dateOfBirth, city: city);
        // Cache is best-effort only; a Hive failure must not fail registration.
        try {
          await _local.savePatient(result);
        } catch (e) {
          debugPrint('[CACHE] patient cache failed (ignored): $e');
        }
        return result;
      } catch (_) {
        setOnline(false);
      }
    }
    final result = await _local.registerPatient(name: name, gender: gender, dateOfBirth: dateOfBirth, city: city);
    _enqueueSync('/api/v1/patients', 'POST', {
      'name': name, 'gender': gender, 'dateOfBirth': dateOfBirth, 'city': city,
    });
    return result;
  }

  @override
  Future<Map<String, dynamic>> bookAppointment({
    required String patientId,
    required String doctorName,
    required String specialty,
    required String location,
    required String date,
    required String doctorId,
    String startTime = '',
    String endTime = '',
    String reason = '',
  }) async {
    if (_online) {
      try {
        return await _remote.bookAppointment(
          patientId: patientId, doctorName: doctorName, specialty: specialty,
          location: location, date: date, doctorId: doctorId,
          startTime: startTime, endTime: endTime, reason: reason,
        );
      } catch (_) {
        setOnline(false);
      }
    }
    final result = await _local.bookAppointment(
      patientId: patientId, doctorName: doctorName, specialty: specialty,
      location: location, date: date, doctorId: doctorId,
      startTime: startTime, endTime: endTime, reason: reason,
    );
    _enqueueSync('/api/v1/appointments', 'POST', {
      'patientId': patientId, 'doctorName': doctorName, 'specialty': specialty,
      'location': location, 'date': date, 'doctorId': doctorId,
    });
    return result;
  }

  @override
  Future<void> markNotificationRead(String notificationId) async {
    if (_online) {
      try {
        await _remote.markNotificationRead(notificationId);
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.markNotificationRead(notificationId);
    _enqueueSync('/api/v1/notifications/$notificationId/read', 'PATCH', {});
  }

  @override
  Future<void> markAllNotificationsRead() async {
    if (_online) {
      try {
        await _remote.markAllNotificationsRead();
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.markAllNotificationsRead();
    _enqueueSync('/api/v1/notifications/read-all', 'PATCH', {});
  }

  Future<int> synchronize() async {
    if (!_online || _syncQueue.isSyncing) return 0;
    _syncQueue.isSyncing = true;
    int synced = 0;
    final pending = List<SyncOperation>.from(_syncQueue.pending);
    for (final op in pending) {
      try {
        await _executeSyncOp(op);
        _syncQueue.remove(op.id);
        synced++;
      } catch (_) {
        op.retryCount++;
        if (op.retryCount >= 3) {
          _syncQueue.remove(op.id);
        }
      }
    }
    _syncQueue.isSyncing = false;
    return synced;
  }

  @override
  Future<List<Map<String, dynamic>>> getAppointments(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getAppointments(patientId),
      local: () => _local.getAppointments(patientId),
      cacheLocally: (List<Map<String, dynamic>> a) => _local.saveAppointments(a),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAvailableSlots(String doctorId, String date) async {
    return _remote.getAvailableSlots(doctorId, date);
  }

  @override
  Future<List<Map<String, dynamic>>> getPatientMedicalRecords(String patientId) async {
    return _remote.getPatientMedicalRecords(patientId);
  }

  @override
  Future<List<Map<String, dynamic>>> getPrescriptions(String patientId) async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getPrescriptions(patientId),
      local: () => _local.getPrescriptions(patientId),
      cacheLocally: (_) {},
    );
  }

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String chatId,
    required String content,
    String? messageType,
  }) async {
    if (_online) {
      try {
        return await _remote.sendMessage(chatId: chatId, content: content, messageType: messageType);
      } catch (_) {
        setOnline(false);
      }
    }
    return _local.sendMessage(chatId: chatId, content: content, messageType: messageType);
  }

  @override
  Future<void> markChatAsRead(String chatId) async {
    if (_online) {
      try {
        await _remote.markChatAsRead(chatId);
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.markChatAsRead(chatId);
  }

  @override
  Future<void> updatePatient(Map<String, dynamic> data) async {
    if (_online) {
      try {
        await _remote.updatePatient(data);
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.updatePatient(data);
    _enqueueSync('/api/v1/patients/profile', 'PATCH', data);
  }

  @override
  Future<Map<String, dynamic>> triggerSos({
    String? location,
    String? type,
    String? notes,
  }) async {
    if (_online) {
      try {
        return await _remote.triggerSos(location: location, type: type, notes: notes);
      } catch (_) {}
    }
    return _local.triggerSos(location: location, type: type, notes: notes);
  }

  @override
  Future<Map<String, dynamic>> getCriticalInfo() async {
    if (_online) {
      try {
        return await _remote.getCriticalInfo();
      } catch (_) {
        setOnline(false);
      }
    }
    return _local.getCriticalInfo();
  }

  @override
  Future<List<HospitalInfo>> getNearbyHospitals() async {
    return _fetchWithRemoteCache(
      remote: () => _remote.getNearbyHospitals(),
      local: () => _local.getNearbyHospitals(),
      cacheLocally: (_) {},
    );
  }

  @override
  Future<void> cancelAppointment(String appointmentId, {String? reason}) async {
    if (_online) {
      try {
        await _remote.cancelAppointment(appointmentId, reason: reason);
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.cancelAppointment(appointmentId, reason: reason);
    _enqueueSync('/api/v1/appointments/$appointmentId/cancel', 'PATCH', {'cancellationReason': reason});
  }

  @override
  Future<void> rescheduleAppointment(String appointmentId, {
    required String date,
    required String startTime,
    required String endTime,
    String? reason,
  }) async {
    if (_online) {
      try {
        await _remote.rescheduleAppointment(appointmentId, date: date, startTime: startTime, endTime: endTime, reason: reason);
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.rescheduleAppointment(appointmentId, date: date, startTime: startTime, endTime: endTime, reason: reason);
    _enqueueSync('/api/v1/appointments/$appointmentId/reschedule', 'PATCH', {
      'appointmentDate': date, 'startTime': startTime, 'endTime': endTime, 'reason': reason,
    });
  }

  @override
  Future<void> confirmAppointment(String appointmentId) async {
    if (_online) {
      try {
        await _remote.confirmAppointment(appointmentId);
        return;
      } catch (_) {
        setOnline(false);
      }
    }
    await _local.confirmAppointment(appointmentId);
    _enqueueSync('/api/v1/appointments/$appointmentId/confirm', 'PATCH', {});
  }

  @override
  Future<String?> uploadAvatar(String filePath, {String? patientId}) async {
    if (_online) {
      try {
        return await _remote.uploadAvatar(filePath, patientId: patientId);
      } catch (_) {
        setOnline(false);
      }
    }
    return _local.uploadAvatar(filePath, patientId: patientId);
  }

  @override
  Future<bool> sendOtp({required String phone, String? email}) async {
    if (_online) {
      try {
        return await _remote.sendOtp(phone: phone, email: email);
      } catch (_) {
        return false;
      }
    }
    return _local.sendOtp(phone: phone, email: email);
  }

  @override
  Future<bool> verifyOtp({required String phone, required String otp, String? email}) async {
    if (_online) {
      try {
        return await _remote.verifyOtp(phone: phone, otp: otp, email: email);
      } catch (_) {
        return false;
      }
    }
    return _local.verifyOtp(phone: phone, otp: otp, email: email);
  }

  @override
  Future<AccessGrant> grantAccess({
    required String doctorId,
    required String accessLevel,
    String? reason,
    String? expiresAt,
  }) async {
    if (_online) {
      try {
        return await _remote.grantAccess(doctorId: doctorId, accessLevel: accessLevel, reason: reason, expiresAt: expiresAt);
      } catch (_) {
        setOnline(false);
      }
    }
    return _local.grantAccess(doctorId: doctorId, accessLevel: accessLevel, reason: reason, expiresAt: expiresAt);
  }

  Future<void> _executeSyncOp(SyncOperation op) async {
    final endpoint = op.endpoint;
    switch (op.type) {
      case 'POST':
        if (endpoint.contains('/cards/')) {
          await _remote.requestCardReissue(op.body['patientId'] as String? ?? '');
        } else if (endpoint.contains('/appointments')) {
          await _remote.bookAppointment(
            patientId: op.body['patientId'] as String? ?? '',
            doctorName: op.body['doctorName'] as String? ?? '',
            specialty: op.body['specialty'] as String? ?? '',
            location: op.body['location'] as String? ?? '',
            date: op.body['date'] as String? ?? '',
            doctorId: op.body['doctorId'] as String? ?? '',
          );
        } else {
          await _remote.registerPatient(
            name: op.body['name'] as String? ?? '',
            gender: op.body['gender'] as String? ?? '',
            dateOfBirth: op.body['dateOfBirth'] as String? ?? '',
            city: op.body['city'] as String? ?? '',
          );
        }
        break;
      case 'PATCH':
        if (endpoint.contains('/notifications/')) {
          if (endpoint.contains('read-all')) {
            await _remote.markAllNotificationsRead();
          } else {
            final id = endpoint.split('/')[4];
            await _remote.markNotificationRead(id);
          }
        } else if (endpoint.contains('/access/')) {
          if (endpoint.contains('/approve')) {
            final id = endpoint.split('/')[4];
            await _remote.approveAccessRequest(id);
          } else if (endpoint.contains('/revoke')) {
            final id = endpoint.split('/')[4];
            await _remote.revokeAccess(id);
          }
        } else if (endpoint.contains('/appointments/')) {
          if (endpoint.contains('/cancel')) {
            final id = endpoint.split('/')[4];
            await _remote.cancelAppointment(id, reason: op.body['cancellationReason'] as String?);
          } else if (endpoint.contains('/reschedule')) {
            final id = endpoint.split('/')[4];
            await _remote.rescheduleAppointment(id,
              date: op.body['appointmentDate'] as String? ?? '',
              startTime: op.body['startTime'] as String? ?? '',
              endTime: op.body['endTime'] as String? ?? '',
              reason: op.body['reason'] as String?,
            );
          } else if (endpoint.contains('/confirm')) {
            final id = endpoint.split('/')[4];
            await _remote.confirmAppointment(id);
          }
        } else if (endpoint.contains('/patients/')) {
          await _remote.updatePatient(op.body);
        }
        break;
    }
  }

  void dispose() {
    _onlineController.close();
  }
}
