import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/api_client.dart';
import 'persistent_sync_queue.dart';

/// Service de synchronisation automatique qui:
/// 1. Envoie les modifications locales au backend MongoDB
/// 2. Réessaye automatiquement en cas d'échec
/// 3. Fonctionne en arrière-plan
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.read(apiClientProvider));
});

class SyncService {
  final ApiClient _apiClient;
  final PersistentSyncQueue _queue = PersistentSyncQueue();
  
  Timer? _periodicSyncTimer;
  bool _isSyncing = false;
  bool _isOnline = true;

  SyncService(this._apiClient);

  /// Initialise le service et démarre la sync périodique
  Future<void> init() async {
    await _queue.init();
    
    // Synchroniser immédiatement au démarrage
    await synchronize();
    
    // Puis toutes les 30 secondes
    _periodicSyncTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => synchronize(),
    );
    
    if (kDebugMode) {
      print('[SyncService] Initialisé - Sync périodique toutes les 30s');
    }
  }

  /// Ajoute une opération à la queue de synchronisation
  Future<void> enqueue({
    required String method,
    required String endpoint,
    Map<String, dynamic>? data,
    String? entityType,
    String? entityId,
  }) async {
    final operation = SyncOperation(
      method: method,
      endpoint: endpoint,
      data: data,
      entityType: entityType,
      entityId: entityId,
    );
    
    await _queue.enqueue(operation);
    
    // Tenter une synchronisation immédiate si online
    if (_isOnline && !_isSyncing) {
      unawaited(synchronize());
    }
  }

  /// Synchronise toutes les opérations en attente
  Future<void> synchronize() async {
    if (_isSyncing || _queue.isEmpty) return;
    
    _isSyncing = true;
    
    try {
      final operations = _queue.getAll();
      
      if (kDebugMode) {
        print('[SyncService] Synchronisation de ${operations.length} opérations');
      }
      
      for (final operation in operations) {
        final success = await _syncOperation(operation);
        
        if (success) {
          await _queue.remove(operation);
        } else {
          // Réessayer plus tard si échec réseau
          if (operation.retryCount < 3) {
            await _queue.remove(operation);
            await _queue.enqueue(operation.withRetry());
          } else {
            // Abandonner après 3 tentatives
            if (kDebugMode) {
              print('[SyncService] Abandon après 3 tentatives: ${operation.id}');
            }
            await _queue.remove(operation);
          }
        }
      }
      
      _isOnline = true;
    } catch (e) {
      _isOnline = false;
      if (kDebugMode) print('[SyncService] Erreur sync: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Synchronise une opération individuelle
  Future<bool> _syncOperation(SyncOperation operation) async {
    try {
      Response response;
      
      switch (operation.method.toUpperCase()) {
        case 'POST':
          response = await _apiClient.dio.post(
            operation.endpoint,
            data: operation.data,
          );
          break;
        case 'PUT':
          response = await _apiClient.dio.put(
            operation.endpoint,
            data: operation.data,
          );
          break;
        case 'PATCH':
          response = await _apiClient.dio.patch(
            operation.endpoint,
            data: operation.data,
          );
          break;
        case 'DELETE':
          response = await _apiClient.dio.delete(
            operation.endpoint,
            data: operation.data,
          );
          break;
        default:
          if (kDebugMode) {
            print('[SyncService] Méthode HTTP inconnue: ${operation.method}');
          }
          return false;
      }
      
      final success = response.statusCode != null && 
                     response.statusCode! >= 200 && 
                     response.statusCode! < 300;
      
      if (success && kDebugMode) {
        print('[SyncService] ✓ Synchronisé: ${operation.method} ${operation.endpoint}');
      }
      
      return success;
    } on DioException catch (e) {
      if (kDebugMode) {
        print('[SyncService] ✗ Échec sync: ${e.response?.statusCode} ${operation.endpoint}');
      }
      
      // Erreur réseau (timeout, no connection) → réessayer
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        _isOnline = false;
        return false;
      }
      
      // Erreur serveur (5xx) → réessayer
      if (e.response?.statusCode != null && 
          e.response!.statusCode! >= 500) {
        return false;
      }
      
      // Erreur client (4xx) → ne pas réessayer (données invalides)
      return true;
    } catch (e) {
      if (kDebugMode) print('[SyncService] Erreur inattendue: $e');
      return false;
    }
  }

  /// Nombre d'opérations en attente
  int get pendingCount => _queue.length;

  /// Vérifie si en ligne
  bool get isOnline => _isOnline;

  /// Arrête le service
  void dispose() {
    _periodicSyncTimer?.cancel();
    _periodicSyncTimer = null;
  }
}
