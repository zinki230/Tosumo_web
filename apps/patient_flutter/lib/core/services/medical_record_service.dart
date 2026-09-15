import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/booklet_entry.dart';

class MedicalRecordVersion {
  final String id;
  final String entryId;
  final int version;
  final Map<String, dynamic> snapshot;
  final DateTime createdAt;
  final String changedBy;

  MedicalRecordVersion({
    required this.id,
    required this.entryId,
    required this.version,
    required this.snapshot,
    required this.changedBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class MedicalRecordService {
  final List<MedicalRecordVersion> _versions = [];

  void captureVersion(BookletEntry entry, String changedBy) {
    _versions.add(MedicalRecordVersion(
      id: 'ver-${DateTime.now().millisecondsSinceEpoch}',
      entryId: entry.id,
      version: _versions.where((v) => v.entryId == entry.id).length + 1,
      snapshot: entry.toJson(),
      changedBy: changedBy,
    ));
  }

  List<MedicalRecordVersion> getHistory(String entryId) {
    return _versions.where((v) => v.entryId == entryId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  MedicalRecordVersion? getLatestVersion(String entryId) {
    final history = getHistory(entryId);
    return history.isNotEmpty ? history.first : null;
  }

  void clear() {
    _versions.clear();
  }
}

final medicalRecordServiceProvider = Provider<MedicalRecordService>((ref) {
  return MedicalRecordService();
});
