import 'package:hive_flutter/hive_flutter.dart';

class SyncOperation {
  final String id;
  final String type;
  final String endpoint;
  final Map<String, dynamic> body;
  final DateTime createdAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.endpoint,
    required this.body,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'endpoint': endpoint,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    id: json['id'] as String,
    type: json['type'] as String,
    endpoint: json['endpoint'] as String,
    body: Map<String, dynamic>.from(json['body'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    retryCount: json['retryCount'] as int? ?? 0,
  );
}

class SyncQueue {
  static const String _boxName = 'sync_queue';

  final List<SyncOperation> _queue = [];
  bool isSyncing = false;

  List<SyncOperation> get pending => List.unmodifiable(_queue);

  Future<void> init() async {
    await _ensureBox();
    final box = Hive.box(_boxName);
    for (final item in box.values) {
      try {
        if (item is Map) {
          _queue.add(SyncOperation.fromJson(Map<String, dynamic>.from(item)));
        }
      } catch (_) {
        // ignore malformed
      }
    }
  }

  Future<Box<dynamic>> _ensureBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox(_boxName);
    }
    return Hive.box(_boxName);
  }

  void enqueue(SyncOperation operation) {
    _queue.add(operation);
    _persist();
  }

  void enqueueAll(List<SyncOperation> operations) {
    _queue.addAll(operations);
    _persist();
  }

  void remove(String id) {
    _queue.removeWhere((op) => op.id == id);
    _persist();
  }

  void clear() {
    _queue.clear();
    _persist();
  }

  bool get hasPending => _queue.isNotEmpty;

  List<Map<String, dynamic>> toJson() =>
      _queue.map((op) => op.toJson()).toList();

  void loadFromJson(List<dynamic> json) {
    _queue.clear();
    for (final item in json) {
      if (item is Map) {
        _queue.add(SyncOperation.fromJson(Map<String, dynamic>.from(item)));
      }
    }
  }

  void _persist() {
    if (!Hive.isBoxOpen(_boxName)) {
      Hive.openBox(_boxName).then((_) => _persistIn());
      return;
    }
    _persistIn();
  }

  void _persistIn() {
    final box = Hive.box(_boxName);
    box.clear();
    final items = toJson();
    for (var i = 0; i < items.length; i++) {
      box.put(i, items[i]);
    }
  }
}
