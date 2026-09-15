class DoctorResponseMapper {
  DoctorResponseMapper._();

  static Map<String, dynamic> doctorFromBackend(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    final institutions = json['institutions'] as List<dynamic>?;
    Map<String, dynamic>? primaryInstitution;
    if (institutions != null && institutions.isNotEmpty) {
      final first = institutions.first as Map<String, dynamic>;
      primaryInstitution = first['institution'] as Map<String, dynamic>?;
    }

    final workingHoursRaw = json['workingHours'] as List<dynamic>?;
    final mappedWorkHours = workingHoursRaw?.map((wh) {
      final whMap = wh as Map<String, dynamic>;
      return <String, dynamic>{
        'dayOfWeek': whMap['dayOfWeek'] ?? whMap['dayOfWeek'] ?? 0,
        'startTime': whMap['startTime'] as String? ?? '08:00',
        'endTime': whMap['endTime'] as String? ?? '17:00',
        'isAvailable': whMap['isAvailable'] as bool? ?? true,
      };
    }).toList() ?? <Map<String, dynamic>>[];

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'name': '${user?['firstName'] as String? ?? json['firstName'] as String? ?? ''} ${user?['lastName'] as String? ?? json['lastName'] as String? ?? ''}'.trim(),
      'email': user?['email'] as String? ?? '',
      'phone': user?['phone'] as String? ?? '',
      'specialty': json['specialty'] as String? ?? '',
      'hospitalId': primaryInstitution?['id'] as String? ?? json['institutionId'] as String? ?? '',
      'hospitalName': primaryInstitution?['name'] as String? ?? json['hospitalName'] as String? ?? '',
      'licenseNumber': json['licenseNumber'] as String? ?? '',
      'photoUrl': json['profilePhotoUrl'] as String? ?? user?['avatar'] as String? ?? '',
      'rating': (json['averageRating'] as num?)?.toDouble() ?? 0.0,
      'reviewCount': json['totalRatings'] as int? ?? 0,
      'languages': (json['languages'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      'credentials': _parseCredentials(json),
      'expertise': _parseExpertise(json),
      'workingHours': mappedWorkHours,
      'isAvailable': json['isAvailable'] as bool? ?? true,
      'createdAt': json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    };
  }

  static String _patientName(Map<String, dynamic> json, Map<String, dynamic>? user) {
    final first = json['firstName'] as String? ?? user?['firstName'] as String? ?? '';
    final last = json['lastName'] as String? ?? user?['lastName'] as String? ?? '';
    return '$first $last'.trim();
  }

  static List<String> _parseCredentials(Map<String, dynamic> json) {
    final credentials = <String>[];
    final education = json['education'];
    if (education != null && education is List) {
      for (final e in education) {
        final eMap = e as Map<String, dynamic>;
        final degree = eMap['degree'] as String?;
        if (degree != null) credentials.add(degree);
      }
    }
    final certifications = json['certifications'];
    if (certifications != null && certifications is List) {
      for (final c in certifications) {
        if (c is String) {
          credentials.add(c);
        } else if (c is Map) {
          final name = c['name'] as String? ?? c['title'] as String?;
          if (name != null) credentials.add(name);
        }
      }
    }
    return credentials;
  }

  static List<String> _parseExpertise(Map<String, dynamic> json) {    final expertise = <String>[];
    final experience = json['experience'];
    if (experience != null && experience is List) {
      for (final exp in experience) {
        final expMap = exp as Map<String, dynamic>;
        final area = expMap['area'] as String? ?? expMap['specialty'] as String?;
        if (area != null) expertise.add(area);
      }
    }
    return expertise;
  }

  static Map<String, dynamic> appointmentFromBackend(Map<String, dynamic> json) {
    final patient = json['patient'] as Map<String, dynamic>?;
    final patientUser = patient?['user'] as Map<String, dynamic>?;
    String patientName = '';
    if (patientUser != null) {
      patientName = '${patientUser['firstName'] as String? ?? ''} ${patientUser['lastName'] as String? ?? ''}'.trim();
    } else if (patient != null) {
      patientName = '${patient['firstName'] as String? ?? ''} ${patient['lastName'] as String? ?? ''}'.trim();
    }

    final appointmentDate = json['appointmentDate'] as String? ?? json['date'] as String?;
    final startTime = json['startTime'] as String? ?? '';

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'patientId': json['patientId'] as String? ?? '',
      'patientName': patientName,
      'doctorId': json['doctorId'] as String? ?? '',
      'date': appointmentDate ?? DateTime.now().toIso8601String(),
      'timeSlot': startTime,
      'type': json['type'] as String? ?? 'consultation',
      'status': json['status'] as String? ?? 'pending',
      'reason': json['reason'] as String? ?? '',
      'notes': json['notes'] as String? ?? '',
      'isUrgent': json['isUrgent'] as bool? ?? json['isPaid'] as bool? ?? false,
      'createdAt': json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> patientSummaryFromBackend(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final name = _patientName(json, user);
    final dateOfBirth = json['dateOfBirth'] as String?;
    final lastVisit = json['lastVisit'] as String? ?? json['updatedAt'] as String?;

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'name': name,
      'nationalId': json['nin'] as String? ?? '',
      'dateOfBirth': dateOfBirth ?? DateTime.now().toIso8601String(),
      'bloodType': json['bloodType'] as String? ?? '',
      'gender': json['gender'] as String? ?? '',
      'photoUrl': json['profilePhotoUrl'] as String? ?? user?['avatar'] as String? ?? '',
      'lastVisit': lastVisit ?? DateTime.now().toIso8601String(),
      'isFavorite': json['isFavorite'] as bool? ?? false,
      'conditions': (json['chronicDiseases'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      'allergies': (json['allergies'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      'verified': json['isVerified'] as bool? ?? false,
    };
  }

  static Map<String, dynamic> patientDetailFromBackend(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final name = _patientName(json, user);
    final medicalCard = json['medicalCard'] as Map<String, dynamic>?;
    final emergencyInfos = json['emergencyInfos'] as List<dynamic>?;
    Map<String, dynamic>? primaryEmergency;
    if (emergencyInfos != null) {
      for (final element in emergencyInfos) {
        final info = element as Map<String, dynamic>;
        final isPrimary = info['isPrimary'] as bool? ?? false;
        if (isPrimary || primaryEmergency == null) {
          primaryEmergency = info;
        }
      }
    }

    // Support both chronicDiseases (legacy) and chronicConditions (new)
    final chronicConditions = (json['chronicConditions'] as List<dynamic>?)?.cast<String>() 
        ?? (json['chronicDiseases'] as List<dynamic>?)?.cast<String>() 
        ?? <String>[];
    final allergies = json['allergies'] as List<dynamic>?;

    final dateOfBirth = json['dateOfBirth'] as String?;

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'name': name,
      'nationalId': json['nin'] as String? ?? '',
      'dateOfBirth': dateOfBirth ?? DateTime.now().toIso8601String(),
      'bloodType': json['bloodType'] as String? ?? '',
      'gender': json['gender'] as String? ?? '',
      'photoUrl': json['profilePhotoUrl'] as String? ?? user?['avatar'] as String? ?? '',
      'phone': user?['phone'] as String? ?? json['phone'] as String? ?? '',
      'email': user?['email'] as String? ?? '',
      'address': json['address'] as String? ?? '',
      'city': json['city'] as String? ?? '',
      'region': json['region'] as String? ?? '',
      'height': (json['heightCm'] as num?)?.toDouble(),
      'weight': (json['weightKg'] as num?)?.toDouble(),
      'allergies': allergies?.cast<String>() ?? <String>[],
      'chronicConditions': chronicConditions,
      'currentMeds': (json['currentMeds'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      'emergencyContact': primaryEmergency != null
          ? <String, dynamic>{
              'name': primaryEmergency['fullName'] as String? ?? '',
              'relationship': primaryEmergency['relationship'] as String? ?? '',
              'phone': primaryEmergency['phone'] as String? ?? '',
            }
          : (json['emergencyContactName'] != null || json['emergencyContactPhone'] != null)
              ? <String, dynamic>{
                  'name': json['emergencyContactName'] as String? ?? '',
                  'relationship': json['emergencyContactRelationship'] as String? ?? '',
                  'phone': json['emergencyContactPhone'] as String? ?? '',
                }
              : null,
      'medicalCardNumber': medicalCard?['cardNumber'] as String? ?? '',
      'insuranceProvider': json['insuranceProvider'] as String? ?? '',
      'insuranceNumber': json['insuranceNumber'] as String? ?? '',
      'healthScore': json['healthScore'] as int? ?? 0,
      'lastVisit': json['lastVisit'] as String? ?? json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      'verified': json['isVerified'] == true || (json['bloodType']?.toString().isNotEmpty ?? false),
    };
  }

  static Map<String, dynamic> conversationFromBackend(Map<String, dynamic> json) {
    final participants = json['participants'] as List<dynamic>?;
    final messages = json['messages'] as List<dynamic>?;
    Map<String, dynamic>? lastMessageObj;
    if (messages != null && messages.isNotEmpty) {
      lastMessageObj = messages.first as Map<String, dynamic>;
    }

    String participantName = '';
    String participantRole = 'patient';
    bool online = false;
    if (participants != null) {
      for (final p in participants) {
        final pMap = p as Map<String, dynamic>;
        final doctor = pMap['doctor'] as Map<String, dynamic>?;
        final doctorUser = doctor?['user'] as Map<String, dynamic>?;
        if (doctorUser != null) {
          participantName = '${doctorUser['firstName'] as String? ?? ''} ${doctorUser['lastName'] as String? ?? ''}'.trim();
          participantRole = 'doctor';
          online = doctorUser['isOnline'] as bool? ?? false;
        }
      }
    }

    final lastMsgText = lastMessageObj?['content'] as String? ?? lastMessageObj?['text'] as String? ?? '';
    final lastMsgDateStr = lastMessageObj?['createdAt'] as String? ?? json['updatedAt'] as String?;

    final initials = participantName.isNotEmpty
        ? participantName.split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join()
        : '?';

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'participantName': participantName,
      'participantRole': participantRole,
      'participantInitials': initials,
      'lastMessage': lastMsgText,
      'lastMessageDate': lastMsgDateStr ?? DateTime.now().toIso8601String(),
      'unread': 0,
      'online': online,
      'messages': <Map<String, dynamic>>[],
    };
  }

  static Map<String, dynamic> messageFromBackend(Map<String, dynamic> json) {
    final sender = json['sender'] as Map<String, dynamic>?;
    final senderName = sender != null
        ? '${sender['firstName'] as String? ?? ''} ${sender['lastName'] as String? ?? ''}'.trim()
        : '';
    final senderRole = json['senderRole'] as String? ?? 'patient';

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'conversationId': json['chatId'] as String? ?? '',
      'senderId': json['senderId'] as String? ?? '',
      'senderName': senderName,
      'senderRole': senderRole,
      'text': json['content'] as String? ?? json['text'] as String? ?? '',
      'type': json['messageType'] as String? ?? 'text',
      'metadata': json['metadata'] as Map<String, dynamic>?,
      'status': json['isRead'] == true ? 'read' : 'delivered',
      'timestamp': json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> notificationFromBackend(Map<String, dynamic> json) {
    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'type': json['type'] as String? ?? 'system',
      'title': json['title'] as String? ?? '',
      'message': json['body'] as String? ?? json['message'] as String? ?? '',
      'data': json['data'] as Map<String, dynamic>?,
      'read': json['isRead'] as bool? ?? false,
      'createdAt': json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> emergencySessionFromBackend(Map<String, dynamic> json) {
    final patientSummary = json['patientSummary'] as Map<String, dynamic>?;
    final patient = json['patient'] as Map<String, dynamic>?;
    final patientUser = patient?['user'] as Map<String, dynamic>?;

    Map<String, dynamic>? mappedSummary;
    if (patientSummary != null) {
      mappedSummary = <String, dynamic>{
        'name': patientSummary['name'] as String? ?? '',
        'age': patientSummary['age'] as int? ?? 0,
        'bloodType': patientSummary['bloodType'] as String? ?? '',
        'gender': patientSummary['gender'] as String? ?? '',
        'allergies': (patientSummary['allergies'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        'chronicConditions': (patientSummary['chronicConditions'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        'emergencyContact': patientSummary['emergencyContact'] != null
            ? _emergencyContactFromBackend(patientSummary['emergencyContact'] as Map<String, dynamic>)
            : null,
        'chiefComplaint': patientSummary['chiefComplaint'] as String? ?? '',
        'triageNotes': patientSummary['triageNotes'] as String? ?? '',
      };
    } else if (patientUser != null) {
      mappedSummary = <String, dynamic>{
        'name': '${patientUser['firstName'] as String? ?? ''} ${patientUser['lastName'] as String? ?? ''}'.trim(),
        'age': _calculateAge(patient?['dateOfBirth'] as String?),
        'bloodType': patient?['bloodType'] as String? ?? '',
        'gender': patient?['gender'] as String? ?? '',
        'allergies': (patient?['allergies'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        'chronicConditions': (patient?['chronicDiseases'] as List<dynamic>?)?.cast<String>() ?? <String>[],
        'emergencyContact': null,
        'chiefComplaint': json['chiefComplaint'] as String? ?? '',
        'triageNotes': json['triageNotes'] as String? ?? '',
      };
    }

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'patientId': json['patientId'] as String? ?? '',
      'doctorId': json['doctorId'] as String? ?? '',
      'startedAt': json['startedAt'] as String? ?? json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      'status': json['status'] as String? ?? 'active',
      'patientSummary': mappedSummary,
    };
  }

  static Map<String, dynamic> _emergencyContactFromBackend(Map<String, dynamic> json) {
    return <String, dynamic>{
      'name': json['name'] as String? ?? json['fullName'] as String? ?? '',
      'relationship': json['relationship'] as String? ?? '',
      'phone': json['phone'] as String? ?? '',
    };
  }

  static int _calculateAge(String? dateOfBirth) {
    if (dateOfBirth == null) return 0;
    try {
      final dob = DateTime.parse(dateOfBirth);
      final now = DateTime.now();
      return now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1);
    } catch (_) {
      return 0;
    }
  }

  static Map<String, dynamic> consultationFromBackend(Map<String, dynamic> json) {
    final date = json['date'] as String? ?? json['appointmentDate'] as String? ?? json['createdAt'] as String?;

    final vitalsRaw = json['vitals'] as Map<String, dynamic>? ?? json['vitalSigns'] as Map<String, dynamic>?;
    Map<String, dynamic>? mappedVitals;
    if (vitalsRaw != null) {
      mappedVitals = <String, dynamic>{
        'temperature': (vitalsRaw['temperature'] as num?)?.toDouble(),
        'heartRate': vitalsRaw['heartRate'] as int?,
        'bloodPressureSystolic': vitalsRaw['bloodPressureSystolic'] as int? ?? vitalsRaw['systolic'] as int?,
        'bloodPressureDiastolic': vitalsRaw['bloodPressureDiastolic'] as int? ?? vitalsRaw['diastolic'] as int?,
        'respiratoryRate': vitalsRaw['respiratoryRate'] as int?,
        'oxygenSaturation': (vitalsRaw['oxygenSaturation'] as num?)?.toDouble(),
        'weight': (vitalsRaw['weight'] as num?)?.toDouble(),
        'height': (vitalsRaw['height'] as num?)?.toDouble(),
        'bmi': (vitalsRaw['bmi'] as num?)?.toDouble(),
        'recordedAt': vitalsRaw['recordedAt'] as String?,
      };
    }

    final symptoms = json['symptoms'] as List<dynamic>?;
    final diagnosis = json['diagnosis'] as String? ?? '';
    final clinicalNotes = json['clinicalNotes'] as String? ?? json['notes'] as String? ?? '';
    final physicalExamination = json['physicalExamination'] as String? ?? '';
    final treatment = json['treatment'] as String? ?? json['treatmentPlan'] as String? ?? '';
    final followUpPlan = json['followUpPlan'] as String? ?? '';
    final severity = json['severity'] as String? ?? 'medium';
    final status = json['status'] as String? ?? 'draft';

    final signedAt = json['signedAt'] as String?;
    final signature = json['signature'] as Map<String, dynamic>?;

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'patientId': json['patientId'] as String? ?? '',
      'doctorId': json['doctorId'] as String? ?? '',
      'appointmentId': json['appointmentId'] as String? ?? '',
      'date': date ?? DateTime.now().toIso8601String(),
      'symptoms': symptoms?.cast<String>() ?? <String>[],
      'diagnosis': diagnosis,
      'clinicalNotes': clinicalNotes,
      'vitals': mappedVitals,
      'physicalExamination': physicalExamination,
      'treatment': treatment,
      'followUpPlan': followUpPlan,
      'severity': severity,
      'consultationType': json['consultationType'] as String? ?? 'Routine',
      'facility': json['facility'] as String? ?? '',
      'chiefComplaint': json['chiefComplaint'] as String? ?? '',
      'differentialDiagnosis': json['differentialDiagnosis'] as String? ?? '',
      'doctorNotes': json['doctorNotes'] as String? ?? '',
      'recommendations': json['recommendations'] as String? ?? '',
      'signature': signature,
      'status': status,
      'signedAt': signedAt,
      'orderedExams': (json['orderedExams'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
          <Map<String, dynamic>>[],
      'createdAt': json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> prescriptionFromBackend(Map<String, dynamic> json) {
    final medicationsRaw = json['medications'] as List<dynamic>? ?? <dynamic>[];
    final mappedMeds = medicationsRaw.map((m) {
      final mMap = m as Map<String, dynamic>;
      return <String, dynamic>{
        'name': mMap['name'] as String? ?? mMap['medicationName'] as String? ?? '',
        'dosage': mMap['dosage'] as String? ?? '',
        'frequency': mMap['frequency'] as String? ?? '',
        'duration': mMap['duration'] as String? ?? '',
        'route': mMap['route'] as String? ?? '',
        'instructions': mMap['instructions'] as String? ?? '',
      };
    }).toList();

    if (mappedMeds.isEmpty && (json['medicationName']?.toString().isNotEmpty ?? false)) {
      mappedMeds.add(<String, dynamic>{
        'name': json['medicationName'] as String? ?? '',
        'dosage': json['dosage'] as String? ?? '',
        'frequency': json['frequency'] as String? ?? '',
        'duration': json['duration'] as String? ?? '',
        'route': json['route'] as String? ?? '',
        'instructions': json['instructions'] as String? ?? '',
      });
    }

    final issueDate = json['issueDate'] as String? ?? json['prescribedDate'] as String? ?? json['createdAt'] as String? ?? DateTime.now().toIso8601String();
    final expiryDate = json['expiryDate'] as String?;

    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'patientId': json['patientId'] as String? ?? '',
      'doctorId': json['doctorId'] as String? ?? '',
      'consultationId': json['consultationId'] as String? ?? '',
      'medications': mappedMeds,
      'notes': json['notes'] as String? ?? json['instructions'] as String? ?? '',
      'issueDate': issueDate,
      'expiryDate': expiryDate ?? issueDate,
      'isRenewed': json['isRenewed'] as bool? ?? false,
      'status': json['status'] as String? ?? 'active',
      'createdAt': json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      'signature': json['signature'] as Map<String, dynamic>?,
      'signedAt': json['signedAt'] as String?,
    };
  }

  static Map<String, dynamic> labRequestFromBackend(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'] as List<dynamic>? ?? <dynamic>[];
    final mappedAttachments = attachmentsRaw.map((a) {
      final aMap = a as Map<String, dynamic>;
      return <String, dynamic>{
        'name': aMap['name'] as String? ?? '',
        'url': aMap['url'] as String? ?? aMap['fileUrl'] as String? ?? '',
        'type': aMap['type'] as String? ?? aMap['mimeType'] as String? ?? '',
      };
    }).toList();

    final status = json['status'] as String? ?? 'ordered';
    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'patientId': json['patientId'] as String? ?? '',
      'doctorId': json['doctorId'] as String? ?? '',
      'consultationId': json['consultationId'] as String? ?? '',
      'testName': json['testName'] as String? ?? json['name'] as String? ?? '',
      'testType': json['testType'] as String? ?? json['type'] as String? ?? '',
      'status': _normalizeLabStatus(status),
      'resultValue': json['resultValue'] as String? ?? json['result'] as String?,
      'referenceRange': json['referenceRange'] as String? ?? '',
      'interpretation': json['interpretation'] as String?,
      'attachments': mappedAttachments,
      'orderedAt': json['orderedAt'] as String? ?? json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      'completedAt': json['completedAt'] as String?,
      'notes': json['notes'] as String? ?? '',
      'signature': json['signature'] as Map<String, dynamic>?,
      'signedAt': json['signedAt'] as String?,
    };
  }

  static String _normalizeLabStatus(String status) {
    switch (status) {
      case 'completed':
      case 'reviewed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  static String _normalizeImagingStatus(String status) {
    switch (status) {
      case 'completed':
      case 'reviewed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  static Map<String, dynamic> imagingRequestFromBackend(Map<String, dynamic> json) {
    final attachmentsRaw = json['attachments'] as List<dynamic>? ?? <dynamic>[];
    final mappedAttachments = attachmentsRaw.map((a) {
      final aMap = a as Map<String, dynamic>;
      return <String, dynamic>{
        'name': aMap['name'] as String? ?? '',
        'url': aMap['url'] as String? ?? aMap['fileUrl'] as String? ?? '',
        'type': aMap['type'] as String? ?? aMap['mimeType'] as String? ?? '',
      };
    }).toList();

    final status = json['status'] as String? ?? 'ordered';
    return <String, dynamic>{
      'id': json['id'] as String? ?? '',
      'patientId': json['patientId'] as String? ?? '',
      'doctorId': json['doctorId'] as String? ?? '',
      'consultationId': json['consultationId'] as String? ?? '',
      'imagingType': json['imagingType'] as String? ?? json['type'] as String? ?? '',
      'bodyPart': json['bodyPart'] as String? ?? '',
      'status': _normalizeImagingStatus(status),
      'findings': json['findings'] as String?,
      'impression': json['impression'] as String?,
      'attachments': mappedAttachments,
      'orderedAt': json['orderedAt'] as String? ?? json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      'completedAt': json['completedAt'] as String?,
      'notes': json['notes'] as String? ?? '',
      'signature': json['signature'] as Map<String, dynamic>?,
      'signedAt': json['signedAt'] as String?,
    };
  }

  static Map<String, dynamic> dashboardStatsFromBackend(Map<String, dynamic> json) {
    final stats = json['stats'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final recent = (json['recentAppointments'] as List<dynamic>?)
            ?.map((e) => appointmentFromBackend(e as Map<String, dynamic>))
            .toList() ??
        <Map<String, dynamic>>[];
    final upcoming = (json['upcomingAppointments'] as List<dynamic>?)
            ?.map((e) => appointmentFromBackend(e as Map<String, dynamic>))
            .toList() ??
        <Map<String, dynamic>>[];

    return <String, dynamic>{
      'totalAppointments': stats['totalAppointments'] as int? ?? 0,
      'todayAppointments': stats['todayAppointments'] as int? ?? 0,
      'pendingApprovals': stats['pendingApprovals'] as int? ?? 0,
      'totalPatients': stats['totalPatients'] as int? ?? 0,
      'recentAppointments': recent,
      'upcomingAppointments': upcoming,
    };
  }

  static Map<String, dynamic> criticalInfoFromBackend(Map<String, dynamic> json) {
    final emergencyContact = json['emergencyContact'] as Map<String, dynamic>?;
    return <String, dynamic>{
      'name': json['name'] as String? ?? '',
      'age': json['age'] as int? ?? 0,
      'bloodType': json['bloodType'] as String? ?? '',
      'gender': json['gender'] as String? ?? '',
      'allergies': (json['allergies'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      'chronicConditions': (json['chronicDiseases'] as List<dynamic>?)?.cast<String>() ?? <String>[],
      'emergencyContact': emergencyContact != null
          ? _emergencyContactFromBackend(emergencyContact)
          : null,
      'chiefComplaint': json['chiefComplaint'] as String? ?? '',
      'triageNotes': json['triageNotes'] as String? ?? '',
    };
  }

  static List<Map<String, dynamic>> availabilityFromBackend(List<dynamic> slots) {
    return slots.map((e) {
      final slot = e as Map<String, dynamic>;
      return <String, dynamic>{
        'dayOfWeek': slot['dayOfWeek'] as int? ?? 0,
        'startTime': slot['startTime'] as String? ?? '08:00',
        'endTime': slot['endTime'] as String? ?? '17:00',
        'isAvailable': slot['isAvailable'] as bool? ?? true,
        'slotDuration': slot['slotDuration'] as int? ?? 30,
      };
    }).toList();
  }
}