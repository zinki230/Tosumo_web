import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

final localDatabaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase());

class LocalDatabase {
  String? _basePath;

  LocalDatabase();

  Future<void> init() async {
    if (kIsWeb) {
      await Hive.initFlutter();
      return;
    }
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

  Box<dynamic> _box(String name) {
    return Hive.box(name);
  }

  Future<void> _ensureBox(String name) async {
    if (!Hive.isBoxOpen(name)) {
      await Hive.openBox(name);
    }
  }

  Future<List<T>> getAll<T>(
    String boxName,
    T Function(Map<String, dynamic> json) fromJson,
  ) async {
    await _ensureBox(boxName);
    final box = _box(boxName);
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
    await _ensureBox(boxName);
    final box = _box(boxName);
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
    await _ensureBox(boxName);
    final box = _box(boxName);
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
    Map<String, dynamic> Function(T) toJson,
  ) async {
    await _ensureBox(boxName);
    final box = _box(boxName);
    String? existingKey;
    for (final key in box.keys) {
      final val = box.get(key);
      if (val is Map && val['id'] == id) {
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
    await _ensureBox(boxName);
    final box = _box(boxName);
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
    await _ensureBox(boxName);
    await _box(boxName).clear();
  }
}
