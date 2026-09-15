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
  final List<SyncOperation> _queue = [];
  bool isSyncing = false;
  void Function()? onChanged;

  List<SyncOperation> get pending => List.unmodifiable(_queue);

  void enqueue(SyncOperation operation) {
    _queue.add(operation);
    onChanged?.call();
  }

  void enqueueAll(List<SyncOperation> operations) {
    _queue.addAll(operations);
    onChanged?.call();
  }

  void remove(String id) {
    _queue.removeWhere((op) => op.id == id);
    onChanged?.call();
  }

  void clear() {
    _queue.clear();
    onChanged?.call();
  }

  bool get hasPending => _queue.isNotEmpty;

  List<Map<String, dynamic>> toJson() =>
      _queue.map((op) => op.toJson()).toList();

  void loadFromJson(List<dynamic> json) {
    _queue.clear();
    for (final item in json) {
      _queue.add(SyncOperation.fromJson(Map<String, dynamic>.from(item)));
    }
  }
}
