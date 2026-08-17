class CustomPlaylist {
  final String id;
  final String name;
  final List<int> trackIds;
  final int createdAt;

  CustomPlaylist({
    required this.id,
    required this.name,
    List<int>? trackIds,
    required this.createdAt,
  }) : trackIds = trackIds ?? [];

  CustomPlaylist copyWith({
    String? id,
    String? name,
    List<int>? trackIds,
    int? createdAt,
  }) {
    return CustomPlaylist(
      id: id ?? this.id,
      name: name ?? this.name,
      trackIds: trackIds ?? this.trackIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'trackIds': trackIds,
        'createdAt': createdAt,
      };

  factory CustomPlaylist.fromJson(Map<String, dynamic> json) {
    return CustomPlaylist(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      trackIds: (json['trackIds'] as List? ?? []).cast<int>(),
      createdAt: json['createdAt'] as int? ?? 0,
    );
  }
}