class QueueSnapshot {
  final String name;
  final int createdAt;
  final List<int> trackIds;

  const QueueSnapshot({
    required this.name,
    required this.createdAt,
    required this.trackIds,
  });

  factory QueueSnapshot.fromJson(Map<String, dynamic> json) {
    return QueueSnapshot(
      name: json['name'] as String,
      createdAt: json['createdAt'] as int,
      trackIds: (json['trackIds'] as List).cast<int>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'createdAt': createdAt,
        'trackIds': trackIds,
      };
}