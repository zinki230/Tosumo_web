class BoxItem {
  final String id;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  DateTime updatedAt;
  String syncStatus;
  int version;
  bool deleted;

  BoxItem({
    required this.id,
    required this.data,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.syncStatus = 'pending',
    this.version = 1,
    this.deleted = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'syncStatus': syncStatus,
    'version': version,
    'deleted': deleted,
  };

  factory BoxItem.fromJson(Map<String, dynamic> json) => BoxItem(
    id: json['id'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    syncStatus: json['syncStatus'] as String? ?? 'pending',
    version: json['version'] as int? ?? 1,
    deleted: json['deleted'] as bool? ?? false,
  );
}
