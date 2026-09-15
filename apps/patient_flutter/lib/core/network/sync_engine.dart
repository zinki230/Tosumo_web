import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/repositories/repository_providers.dart';
import '../data/repositories/repository_coordinator.dart';
import 'connectivity_service.dart';

final syncEngineProvider = Provider<SyncEngine>((ref) {
  final coordinator = ref.read(repositoryCoordinatorProvider);
  final connectivity = ConnectivityService();
  final engine = SyncEngine(coordinator, connectivity);
  ref.onDispose(() => engine.dispose());
  return engine;
});

class SyncEngine {
  final RepositoryCoordinator _coordinator;
  final ConnectivityService _connectivity;
  StreamSubscription<bool>? _subscription;
  Timer? _retryTimer;
  bool _running = false;

  SyncEngine(this._coordinator, this._connectivity) {
    _initPersistence();
    _startListening();
  }

  void _initPersistence() {
    _coordinator.syncQueue.onChanged = _persistQueue;
    try {
      if (Hive.isBoxOpen('sync_queue')) {
        final box = Hive.box('sync_queue');
        final stored = box.get('pending');
        if (stored != null) {
          _coordinator.syncQueue.loadFromJson(stored as List<dynamic>);
        }
      }
    } catch (_) {}
  }

  void _persistQueue() {
    try {
      final box = Hive.box('sync_queue');
      box.put('pending', _coordinator.syncQueue.toJson());
    } catch (_) {}
  }

  void _startListening() {
    _subscription = _connectivity.onConnectivityChanged.listen((online) {
      _coordinator.setOnline(online);
      if (online) {
        _processQueue();
      }
    });
  }

  Future<void> start() async {
    _running = true;
    final online = await _connectivity.checkNow();
    _coordinator.setOnline(online);
    if (online) {
      await _processQueue();
    }
  }

  Future<void> stop() async {
    _running = false;
    _retryTimer?.cancel();
  }

  Future<int> _processQueue() async {
    if (!_running) return 0;
    if (_coordinator.isOnline) {
      await _coordinator.synchronize();
      _persistQueue();
    }
    if (_coordinator.syncQueue.hasPending) {
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 30), _processQueue);
    }
    return _coordinator.syncQueue.pending.length;
  }

  void dispose() {
    _subscription?.cancel();
    _retryTimer?.cancel();
  }
}
