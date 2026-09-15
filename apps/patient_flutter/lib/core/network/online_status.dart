import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/repository_providers.dart';
import 'connectivity_service.dart';
import 'sync_engine.dart';

enum SyncStatus { online, offline, syncing }

final syncStatusProvider = NotifierProvider<SyncStatusNotifier, SyncStatus>(
  SyncStatusNotifier.new,
);

class SyncStatusNotifier extends Notifier<SyncStatus> {
  StreamSubscription<bool>? _sub;

  @override
  SyncStatus build() {
    final coordinator = ref.read(repositoryCoordinatorProvider);
    _sub = coordinator.onlineStream.listen((online) {
      state = online ? SyncStatus.online : SyncStatus.offline;
    });
    ref.onDispose(() {
      _sub?.cancel();
    });
    return coordinator.isOnline ? SyncStatus.online : SyncStatus.offline;
  }

  Future<void> start() async {
    final coordinator = ref.read(repositoryCoordinatorProvider);
    final connectivity = ConnectivityService();
    final online = await connectivity.checkNow();
    coordinator.setOnline(online);
    state = online ? SyncStatus.online : SyncStatus.offline;
    if (online) {
      await ref.read(syncEngineProvider).start();
    }
  }
}
