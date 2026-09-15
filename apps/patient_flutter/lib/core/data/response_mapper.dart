import '../../../shared/models/patient.dart';
import '../../../shared/models/card_model.dart';
import '../../../shared/models/booklet_entry.dart';
import '../../../shared/models/health_journey_entry.dart';
import '../../../shared/models/doctor_profile.dart';
import '../../../shared/models/notification_model.dart';
import '../../../shared/models/chat_conversation.dart';
import '../../../shared/models/access_grant.dart';

class ResponseMapper {
  static Patient patientFromBackend(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final firstName = (json['firstName'] as String? ?? '').trim();
    final lastName = (json['lastName'] as String? ?? '').trim();
    final combined = '$firstName $lastName'.trim();
    
    // Parse dateOfBirth - handle both String and DateTime from backend
    DateTime parsedDOB = DateTime.now();
    final dobRaw = json['dateOfBirth'];
    if (dobRaw is String && dobRaw.isNotEmpty) {
      try {
        parsedDOB = DateTime.parse(dobRaw);
      } catch (_) {
        parsedDOB = DateTime.now();
      }
    } else if (dobRaw is DateTime) {
      parsedDOB = dobRaw;
    }
    
    return Patient(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      name: combined.isNotEmpty
          ? combined
          : json['name'] as String? ?? '',
      dateOfBirth: parsedDOB,
      nationalId: json['nin'] as String? ?? json['nationalId'] as String? ?? '',
      gender: json['gender'] as String?,
      bloodType: json['bloodType'] as String? ?? '',
      allergies: (json['allergies'] as List<dynamic>?)?.cast<String>() ?? [],
      chronicConditions: (json['chronicConditions'] as List<dynamic>?)?.cast<String>() 
          ?? (json['chronicDiseases'] as List<dynamic>?)?.cast<String>() ?? [],
      currentMeds: (json['currentMeds'] as List<dynamic>?)?.cast<String>() ?? [],
      // Flattened contact info
      phone: user?['phone'] as String? ?? json['phone'] as String? ?? '',
      email: user?['email'] as String? ?? json['email'] as String? ?? '',
      // Flattened emergency contact
      emergencyContactName: json['emergencyContactName'] as String? ?? '',
      emergencyContactRelationship: json['emergencyContactRelationship'] as String? ?? '',
      emergencyContactPhone: json['emergencyContactPhone'] as String? ?? '',
      status: json['isActive'] == true ? 'ACTIVE' : 'INACTIVE',
      verified: json['isVerified'] == true ||
          (json['bloodType']?.toString().isNotEmpty ?? false),
      photoUrl: json['profilePhotoUrl'] as String?,
      city: json['city'] as String? ?? '',
      address: json['address'] as String? ?? '',
    );
  }

  static CardModel medicalCardFromBackend(Map<String, dynamic> json) {
    return CardModel(
      patientId: json['patientId'] as String? ?? '',
      // Prefer the signed QR token issued by the backend (never put sensitive
      // data in the QR). Falls back to the raw card number for legacy codes.
      token: json['qrToken'] as String? ??
          json['cardNumber'] as String? ??
          json['token'] as String? ??
          '',
      status: json['isActive'] == true ? 'ACTIVE' : 'INACTIVE',
      issuedAt: json['issueDate'] as String? ?? json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }

  static BookletEntry bookletEntryFromBackend(Map<String, dynamic> json) {
    return BookletEntry(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      visitDate: json['recordDate'] as String? ?? json['createdAt'] as String? ?? '',
      facility: json['hospitalName'] as String? ?? '',
      summary: json['title'] as String? ?? json['description'] as String? ?? '',
      details: json['description'] as String? ?? '',
      doctorName: json['doctorName'] as String? ?? '',
      doctorSpecialty: '',
      diagnosis: json['diagnosis'] as String? ?? '',
      prescription: json['prescription'] as String? ?? '',
      consultationType: json['bookletType'] as String? ?? 'consultation',
      status: 'completed',
      symptoms: '',
      doctorNotes: '',
    );
  }

  static PrescribedMedication prescriptionFromBackend(Map<String, dynamic> json) {
    String doctorName = '';
    final doc = json['doctor'];
    if (doc is Map) {
      final title = doc['title']?.toString() ?? '';
      final first = doc['firstName']?.toString() ?? '';
      final last = doc['lastName']?.toString() ?? '';
      final combined = '$title $first $last'.trim();
      if (combined.isNotEmpty) doctorName = combined;
    }
    if (doctorName.isEmpty) {
      final dn = json['doctorName']?.toString() ?? '';
      if (dn.isNotEmpty) doctorName = dn.startsWith('Dr') ? dn : 'Dr. $dn';
    }
    return PrescribedMedication(
      id: json['id'] as String? ?? json['_id'] as String? ?? '',
      consultationId: json['consultationId'] as String? ?? '',
      doctorName: doctorName,
      isCompleted: json['isCompleted'] as bool? ?? false,
      drugName: json['medicationName'] as String? ?? json['drugName'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? json['route'] as String? ?? '',
      duration: json['duration'] as String? ?? '',
      instructions: json['instructions'] as String? ?? '',
    );
  }

  static HealthJourneyEntry journeyEntryFromBackend(Map<String, dynamic> json) {
    return HealthJourneyEntry(
      id: json['id'] as String? ?? '',
      patientId: json['patientId'] as String? ?? '',
      date: json['entryDate'] as String? ?? json['createdAt'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['hospitalName'] as String? ?? json['doctorName'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['entryType'] as String? ?? 'consultation',
      icon: _categoryIcon(json['entryType'] as String? ?? ''),
      status: 'completed',
      institution: json['hospitalName'] as String? ?? '',
      doctorName: json['doctorName'] as String?,
    );
  }

  static String _categoryIcon(String type) {
    switch (type) {
      case 'appointment': return 'calendar';
      case 'consultation': return 'stethoscope';
      case 'lab': return 'flask';
      case 'imaging': return 'x-ray';
      case 'prescription': return 'pill';
      case 'hospitalization': return 'ambulance';
      default: return 'activity';
    }
  }

  static DoctorProfile doctorFromBackend(Map<String, dynamic> json) {
    final name = '${json['title'] ?? ''} ${json['firstName'] ?? ''} ${json['lastName'] ?? ''}'.trim();
    return DoctorProfile(
      id: json['id'] as String? ?? '',
      name: name,
      specialty: json['specialty'] as String? ?? '',
      rating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['totalRatings'] as int? ?? 0,
      yearsExperience: json['yearsOfExperience'] as int? ?? 0,
      patientCount: 0,
      bio: json['bio'] as String? ?? '',
      languages: (json['languages'] as List<dynamic>?)?.cast<String>() ?? [],
      hospital: json['address'] as String? ?? '',
      hospitalLocation: '${json['city'] ?? ''}, ${json['region'] ?? ''}'.trim(),
      consultationTypes: ['Routine', 'Suivi'],
      nextAvailableSlot: '',
      availableToday: json['isAvailable'] == true,
      reviews: [],
      credentials: [],
      expertise: [],
    );
  }

  static NotificationModel notificationFromBackend(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      message: json['body'] as String? ?? '',
      time: json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      read: json['isRead'] as bool? ?? false,
    );
  }

  static String _safeStr(dynamic v) => v?.toString() ?? '';
  static String? _nullStr(dynamic v) => v?.toString();
  static Map<String, dynamic> _safeMap(dynamic v) => v is Map<String, dynamic> ? v : v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};
  static String _drName(dynamic doctor) {
    if (doctor is Map) {
      final fn = doctor['firstName']?.toString() ?? '';
      final ln = doctor['lastName']?.toString() ?? '';
      return 'Dr. $fn $ln'.trim();
    }
    return '';
  }

  static Appointment appointmentFromBackend(Map<String, dynamic> json) {
    return Appointment(
      id: _safeStr(json['id']),
      doctorName: json['doctor'] is Map ? _drName(json['doctor']) : _safeStr(json['doctorName']),
      specialty: _safeStr(json['type']),
      location: json['institution'] is Map ? _safeStr((json['institution'] as Map)['name']) : _safeStr(json['location']),
      date: _safeStr(json['appointmentDate']),
      doctorId: _safeStr(json['doctorId']),
      status: _safeStr(json['status']),
      startTime: _safeStr(json['startTime']),
      endTime: _safeStr(json['endTime']),
      reason: _safeStr(json['reason']),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  static String _extractHour(String dateStr) {
    if (dateStr.length >= 13) {
      try {
        return dateStr.substring(11, 13);
      } catch (_) {}
    }
    return '09';
  }

  static Map<String, dynamic> appointmentToBackend(Appointment appointment) {
    final startHour = _extractHour(appointment.date);
    final startMinute = appointment.date.length >= 16 ? appointment.date.substring(14, 16) : '00';
    final startHourNum = int.tryParse(startHour) ?? 9;
    final endHourNum = (startHourNum + 1) % 24;
    final endHour = endHourNum.toString().padLeft(2, '0');
    return {
      'doctorId': appointment.doctorId,
      'appointmentDate': appointment.date,
      'startTime': '$startHour:$startMinute',
      'endTime': '$endHour:00',
      'type': appointment.specialty,
      'reason': 'Consultation with ${appointment.doctorName}',
    };
  }

  static List<Map<String, dynamic>> _safeList(dynamic list) {
    if (list is List) {
      return list.map((e) => e is Map<String, dynamic> ? e : e is Map ? e.cast<String, dynamic>() : <String, dynamic>{}).toList();
    }
    return [];
  }

  static ChatConversation conversationFromBackend(Map<String, dynamic> json) {
    final participants = _safeList(json['participants']);
    final messages = _safeList(json['messages']);
    Map<String, dynamic>? lastMessageObj;
    if (messages.isNotEmpty) {
      lastMessageObj = messages.first;
    }

    String participantName = '';
    String participantRole = 'doctor';
    bool online = false;
    for (final p in participants) {
      final doctorJson = _safeMap(p['doctor']);
      final doctorUser = doctorJson['user'];
      final doctorUserMap = doctorUser is Map<String, dynamic> ? doctorUser : doctorUser is Map ? doctorUser.cast<String, dynamic>() : null;
      if (doctorUserMap != null) {
        participantName = '${_safeStr(doctorJson['firstName'])} ${_safeStr(doctorJson['lastName'])}'.trim();
          if (participantName.isEmpty) {
            participantName = '${_safeStr(doctorUserMap['firstName'])} ${_safeStr(doctorUserMap['lastName'])}'.trim();
          }
        participantRole = _safeStr(doctorJson['specialty']);
          online = doctorUserMap['isOnline'] == true;
      }
    }

    if (participantName.isEmpty) {
      participantName = 'Healthcare Provider';
    }

    final lastMsgText = _safeStr(lastMessageObj?['content']);
    final lastMsgDateStr = _nullStr(lastMessageObj?['createdAt']) ?? _nullStr(json['updatedAt']) ?? _nullStr(json['createdAt']) ?? DateTime.now().toIso8601String();

    final initials = participantName.isNotEmpty
        ? participantName.split(' ').where((s) => s.isNotEmpty).map((s) => s[0]).take(2).join()
        : '?';

    final mappedMessages = _safeList(json['messages'])
        .map((m) => messageFromBackend(m))
        .toList();

    final unreadCount = _safeList(json['messages'])
        .where((m) =>
            (m['senderRole']?.toString() ?? 'patient') != 'patient' &&
            m['isRead'] != true)
        .length;

    return ChatConversation(
      id: _safeStr(json['id']),
      participantName: participantName,
      participantRole: participantRole,
      participantInitials: initials,
      lastMessage: lastMsgText,
      lastMessageDate: lastMsgDateStr,
      unread: unreadCount,
      online: online,
      messages: mappedMessages,
    );
  }

  static ChatMessage messageFromBackend(Map<String, dynamic> json) {
    final senderRole = json['senderRole']?.toString() ?? 'patient';
    Map<String, dynamic>? senderJson;
    final s = json['sender'];
    if (s is Map<String, dynamic>) {
      senderJson = s;
    } else if (s is Map) {
      senderJson = s.cast<String, dynamic>();
    }
    final senderName = senderJson != null
        ? '${senderJson['firstName'] ?? ''} ${senderJson['lastName'] ?? ''}'.trim()
        : senderRole == 'doctor'
            ? 'Doctor'
            : senderRole == 'system'
                ? 'System'
                : 'You';

    String? valStr(dynamic v) => v?.toString();
    Map<String, dynamic>? valMap(dynamic v) => v is Map<String, dynamic> ? v : v is Map ? v.cast<String, dynamic>() : null;

    final metadata = valMap(json['metadata']);
    if (metadata == null) {
      if (json['fileUrl'] != null || json['mimeType'] != null) {
        final mm = MessageMetadata(
          attachmentUrl: valStr(json['fileUrl']),
          fileName: valStr(json['mimeType']),
          fileSize: valStr(json['fileSize']),
        );
        return ChatMessage(
          id: valStr(json['id']) ?? '',
          senderId: valStr(json['senderId']) ?? '',
          senderName: senderName,
          text: valStr(json['content']) ?? valStr(json['text']) ?? '',
          timestamp: valStr(json['createdAt']) ?? DateTime.now().toIso8601String(),
          type: valStr(json['messageType']) ?? 'text',
          metadata: mm,
        );
      }
    }

    MessageMetadata? mappedMetadata;
    if (metadata != null) {
      mappedMetadata = MessageMetadata(
        attachmentUrl: valStr(metadata['attachmentUrl']) ?? valStr(json['fileUrl']),
        duration: valStr(metadata['duration']),
        fileName: valStr(metadata['fileName']),
        fileSize: valStr(metadata['fileSize']) ?? valStr(json['fileSize']),
        prescriptionName: valStr(metadata['prescriptionName']),
        labType: valStr(metadata['labType']),
      );
    }

    return ChatMessage(
      id: _safeStr(json['id']),
      senderId: _safeStr(json['senderId']),
      senderName: senderName,
      text: _nullStr(json['content']) ?? _nullStr(json['text']) ?? '',
      timestamp: _nullStr(json['createdAt']) ?? DateTime.now().toIso8601String(),
      type: _nullStr(json['messageType']) ?? 'text',
      metadata: mappedMetadata,
    );
  }

  static BookletEntry consultationToBooklet(Map<String, dynamic> json) {
    String doctorName = '';
    final doc = json['doctor'];
    if (doc is Map) {
      final title = doc['title']?.toString() ?? '';
      final first = doc['firstName']?.toString() ?? '';
      final last = doc['lastName']?.toString() ?? '';
      doctorName = '$title $first $last'.trim();
    }
    final symptoms = (json['symptoms'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final plan = json['plan']?.toString() ?? '';
    final notes = json['notes']?.toString() ?? '';
    final details = [
      if (plan.isNotEmpty) 'Plan: $plan',
      if (notes.isNotEmpty) notes,
    ].join('\n').trim();
    return BookletEntry(
      id: json['id']?.toString() ?? '',
      patientId: json['patientId']?.toString() ?? '',
      visitDate: json['consultationDate']?.toString() ?? json['createdAt']?.toString() ?? '',
      facility: '',
      summary: json['chiefComplaint']?.toString() ?? 'Consultation',
      details: details,
      doctorName: doctorName,
      diagnosis: json['diagnosis']?.toString() ?? '',
      consultationType: 'consultation',
      status: 'completed',
      symptoms: symptoms.join(', '),
      doctorNotes: notes,
    );
  }

  static AccessGrant accessGrantFromBackend(Map<String, dynamic> json) {
    final grantedTo = _safeMap(json['grantedTo']);
    final grantedBy = _safeMap(json['grantedBy']);

    String institutionName = _safeStr(grantedTo['email']);
    if (institutionName.isEmpty) institutionName = 'Healthcare Provider';
    String institutionId = _safeStr(json['grantedToId']);

    if (grantedBy.isNotEmpty) {
      final byEmail = _safeStr(grantedBy['email']);
      if (byEmail.isNotEmpty) institutionName = byEmail;
    }

    final accessLevel = _safeStr(json['accessLevel']);
    final scope = accessLevel == 'read'
        ? 'Read only'
        : accessLevel == 'write'
            ? 'Read/Write'
            : 'Full access';

    final accessType = _safeStr(json['accessType']);
    final mode = accessType == 'temporary' ? 'AUTOMATIC' : 'MANUAL';

    final isActive = json['isActive'] == true;
    final isApproved = json['isApproved'] == true;
    String status;
    if (!isActive) {
      status = 'REVOKED';
    } else if (!isApproved) {
      status = 'PENDING';
    } else {
      status = 'ACTIVE';
    }

    return AccessGrant(
      id: _safeStr(json['id']),
      patientId: _safeStr(json['patientId']),
      institutionId: institutionId,
      institutionName: institutionName,
      mode: mode,
      scope: scope,
      grantedAt: _nullStr(json['startDate']) ?? _nullStr(json['createdAt']) ?? DateTime.now().toIso8601String(),
      expiresAt: _nullStr(json['endDate']),
      status: status,
    );
  }
}

class Appointment {
  final String id;
  final String doctorName;
  final String specialty;
  final String location;
  final String date;
  final String doctorId;
  final String status;
  final String startTime;
  final String endTime;
  final String reason;
  final double amount;

  Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.location,
    required this.date,
    required this.doctorId,
    this.status = 'pending',
    this.startTime = '',
    this.endTime = '',
    this.reason = '',
    this.amount = 0,
  });

  bool get isUpcoming {
    const active = {'pending', 'approved', 'confirmed', 'rescheduled'};
    if (!active.contains(status)) return false;
    final parsed = DateTime.tryParse(date);
    return parsed != null && parsed.isAfter(DateTime.now());
  }
}


  /// Maps Patient model to backend-compatible format for updates
  static Map<String, dynamic> patientToBackend(Patient patient) {
    return {
      'firstName': patient.name.split(' ').first,
      'lastName': patient.name.split(' ').length > 1 
          ? patient.name.split(' ').skip(1).join(' ') 
          : '',
      'dateOfBirth': patient.dateOfBirth.toIso8601String(),
      'nin': patient.nationalId,
      'gender': patient.gender,
      'bloodType': patient.bloodType,
      'allergies': patient.allergies,
      'chronicConditions': patient.chronicConditions,
      'currentMeds': patient.currentMeds,
      // Flatten emergency contact
      'emergencyContactName': patient.emergencyContactName,
      'emergencyContactRelationship': patient.emergencyContactRelationship,
      'emergencyContactPhone': patient.emergencyContactPhone,
      'city': patient.city,
      'address': patient.address,
      'profilePhotoUrl': patient.photoUrl,
    };
  }
