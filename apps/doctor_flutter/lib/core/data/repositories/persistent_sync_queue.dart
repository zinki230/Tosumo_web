import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

/// Queue de synchronisation PERSISTANTE qui survit aux redémarrages
/// et crashes de l'application. Toutes les opérations hors ligne sont
/// sauvegardées dans Hive et seront rejouées lors de la reconnexion.
class PersistentSyncQueue {
  static const String _boxName = 'sync_queue_persistent';
  static const String _queueKey = 'pending_operations';
  
  Box<dynamic>? _box;
  final List<SyncOperation> _memoryQueue = [];
  bool _initialized = false;

  /// Initialise la queue persistante - À appeler au démarrage de l'app
  Future<void> init() async {
    if (_initialized) return;
    
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
      
      // Charger les opérations sauvegardées
      await _loadFromDisk();
      _initialized = true;
      
      if (kDebugMode) {
        print('[SyncQueue] Initialisé avec ${_memoryQueue.length} opérations en attente');
      }
    } catch (e) {
      if (kDebugMode) print('[SyncQueue] Erreur init: $e');
      _initialized = false;
    }
  }

  /// Charge les opérations depuis Hive vers la mémoire
  Future<void> _loadFromDisk() async {
    try {
      final stored = _box?.get(_queueKey);
      if (stored != null && stored is String) {
        final List<dynamic> decoded = jsonDecode(stored);
        _memoryQueue.clear();
        _memoryQueue.addAll(
          decoded.map((e) => SyncOperation.fromJson(e as Map<String, dynamic>))
        );
      }
    } catch (e) {
      if (kDebugMode) print('[SyncQueue] Erreur chargement: $e');
    }
  }

  /// Sauvegarde les opérations dans Hive
  Future<void> _saveToDisk() async {
    try {
      final encoded = jsonEncode(
        _memoryQueue.map((op) => op.toJson()).toList()
      );
      await _box?.put(_queueKey, encoded);
    } catch (e) {
      if (kDebugMode) print('[SyncQueue] Erreur sauvegarde: $e');
    }
  }

  /// Ajoute une opération à synchroniser
  Future<void> enqueue(SyncOperation operation) async {
    _memoryQueue.add(operation);
    await _saveToDisk();
    
    if (kDebugMode) {
      print('[SyncQueue] Opération ajoutée: ${operation.method} ${operation.endpoint}');
      print('[SyncQueue] Total en queue: ${_memoryQueue.length}');
    }
  }

  /// Récupère toutes les opérations en attente
  List<SyncOperation> getAll() {
    return List.unmodifiable(_memoryQueue);
  }

  /// Supprime une opération après synchronisation réussie
  Future<void> remove(SyncOperation operation) async {
    _memoryQueue.removeWhere((op) => op.id == operation.id);
    await _saveToDisk();
    
    if (kDebugMode) {
      print('[SyncQueue] Opération synchronisée et supprimée: ${operation.id}');
    }
  }

  /// Supprime toutes les opérations
  Future<void> clear() async {
    _memoryQueue.clear();
    await _saveToDisk();
  }

  /// Nombre d'opérations en attente
  int get length => _memoryQueue.length;

  /// Vérifie si la queue est vide
  bool get isEmpty => _memoryQueue.isEmpty;

  /// Vérifie si la queue contient des opérations
  bool get isNotEmpty => _memoryQueue.isNotEmpty;
}

/// Représente une opération à synchroniser avec le backend
class SyncOperation {
  final String id;
  final String method; // POST, PUT, PATCH, DELETE
  final String endpoint;
  final Map<String, dynamic>? data;
  final DateTime createdAt;
  final int retryCount;
  final String? entityType; // appointment, consultation, prescription, etc.
  final String? entityId;

  SyncOperation({
    String? id,
    required this.method,
    required this.endpoint,
    this.data,
    DateTime? createdAt,
    this.retryCount = 0,
    this.entityType,
    this.entityId,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'endpoint': endpoint,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
      'entityType': entityType,
      'entityId': entityId,
    };
  }

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      method: json['method'] as String,
      endpoint: json['endpoint'] as String,
      data: json['data'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
      entityType: json['entityType'] as String?,
      entityId: json['entityId'] as String?,
    );
  }

  /// Crée une copie avec un compteur de retry incrémenté
  SyncOperation withRetry() {
    return SyncOperation(
      id: id,
      method: method,
      endpoint: endpoint,
      data: data,
      createdAt: createdAt,
      retryCount: retryCount + 1,
      entityType: entityType,
      entityId: entityId,
    );
  }
}
