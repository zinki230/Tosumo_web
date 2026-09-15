import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

class LocalDatabase {
  String? _basePath;

  LocalDatabase();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _basePath = dir.path;
    await Hive.initFlutter(dir.path);
  }

  Future<void> clearAll() async {
    await Hive.close();
    if (_basePath != null) {
      final dir = Directory(_basePath!);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
    await Hive.initFlutter(_basePath!);
  }

  Future<void> close() async {
    await Hive.close();
  }

  /// Idempotent, self-healing accessor. Guarantees the box is open before use,
  /// so a missed startup open (or a close/reopen) can never throw
  /// `HiveError: Box not found.` All callers must use this instead of a bare
  /// `Hive.box(name)`.
  Future<void> ensureBox(String name) async {
    // The session box has a canonical typed accessor (Box<String>).
    // It must never be (re)opened untyped, otherwise Hive throws a box-type
    // conflict ("already open and of type Box<dynamic>"). Route it to the
    // typed accessor instead.
    if (name == sessionBoxName) {
      await openSessionBox();
      return;
    }
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox(name);
    }
  }

  /// Single, canonical, typed accessor for the authenticated-patient session
  /// box. Guarantees the box is opened with exactly one type (`Box<String>`)
  /// and reuses it if already open — so it is never reopened with another
  /// type. All reads/writes of the active patient id go through here.
  Future<Box<String>> openSessionBox() async {
    if (Hive.isBoxOpen(sessionBoxName)) {
      return Hive.box<String>(sessionBoxName);
    }
    return Hive.openBox<String>(sessionBoxName);
  }

  Future<Box<T>> box<T>(String name) async {
    await ensureBox(name);
    return Hive.box<T>(name);
  }

  /// Single source of truth for the authenticated patient id in local cache /
  /// offline session restore. Self-heals the `medicard` box.
  static const String sessionBoxName = 'medicard';
  static const String activePatientIdKey = 'activePatientId';

  Future<void> setActivePatientId(String patientId) async {
    final b = await openSessionBox();
    await b.put(activePatientIdKey, patientId);
  }

  Future<String> getActivePatientId() async {
    try {
      final b = await openSessionBox();
      return b.get(activePatientIdKey, defaultValue: '') ?? '';
    } catch (_) {
      return '';
    }
  }

  /// Clears the active patient id on logout / fresh session start. An absent id
  /// forces the next login to resolve the patient id from the authenticated user,
  /// preventing one user's cached id leaking into another's session.
  Future<void> clearActivePatientId() async {
    try {
      final b = await openSessionBox();
      await b.delete(activePatientIdKey);
    } catch (_) {}
  }


  Future<List<T>> getAll<T>(
    String boxName,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    await ensureBox(boxName);
    final box = await this.box(boxName);
    final values = box.values.toList();
    return values
        .whereType<Map>()
        .map((e) => fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> putAll<T>(
    String boxName,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    await ensureBox(boxName);
    final box = await this.box(boxName);
    await box.clear();
    for (final item in items) {
      await box.add(toJson(item));
    }
  }

  Future<T?> getById<T>(
    String boxName,
    String id,
    T Function(Map<String, dynamic> json) fromJson, {
    String idField = 'id',
  }) async {
    await ensureBox(boxName);
    final box = await this.box(boxName);
    for (final entry in box.values) {
      if (entry is Map && entry[idField] == id) {
        return fromJson(Map<String, dynamic>.from(entry));
      }
    }
    return null;
  }

  Future<void> putById<T>(
    String boxName,
    String id,
    T item,
    Map<String, dynamic> Function(T) toJson, {
    String idField = 'id',
  }) async {
    await ensureBox(boxName);
    final box = await this.box(boxName);
    String? existingKey;
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map && val[idField] == id) {
        existingKey = key.toString();
        break;
      }
    }
    if (existingKey != null) {
      await box.put(existingKey, toJson(item));
    } else {
      await box.add(toJson(item));
    }
  }

  Future<void> deleteById(
    String boxName,
    String id, {
    String idField = 'id',
  }) async {
    await ensureBox(boxName);
    final box = await this.box(boxName);
    final keysToRemove = <dynamic>[];
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map && val[idField] == id) {
        keysToRemove.add(key);
      }
    }
    for (final key in keysToRemove) {
      await box.delete(key);
    }
  }

  Future<void> clear(String boxName) async {
    await ensureBox(boxName);
    final box = await this.box(boxName);
    await box.clear();
  }

  Future<void> clearUserCache() async {
    const userBoxes = [
      'medicard_patient',
      'medicard_card',
      'medicard_booklet',
      'medicard_access',
      'medicard_audit',
      'medicard_journey',
      'medicard_chats',
      'medicard_notifications',
      'medicard_appointments',
    ];
    for (final boxName in userBoxes) {
      try {
        await clear(boxName);
      } catch (_) {}
    }
    try {
      await setActivePatientId('');
    } catch (_) {}
  }
}
