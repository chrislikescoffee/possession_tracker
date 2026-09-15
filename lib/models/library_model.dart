class Library {
  final String id;
  final String name;
  final String ownerId;
  final int itemLimit;
  final DateTime createdAt;

  const Library({
    required this.id,
    required this.name,
    required this.ownerId,
    this.itemLimit = 50,
    required this.createdAt,
  });

  factory Library.fromJson(Map<String, dynamic> json) {
    return Library(
      id: json['id'] as String,
      name: json['name'] as String,
      ownerId: json['owner_id'] as String? ?? '',
      itemLimit: json['item_limit'] as int? ?? 50,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'owner_id': ownerId,
        'item_limit': itemLimit,
        'created_at': createdAt.toIso8601String(),
      };

  Library copyWith({
    String? id,
    String? name,
    String? ownerId,
    int? itemLimit,
    DateTime? createdAt,
  }) {
    return Library(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      itemLimit: itemLimit ?? this.itemLimit,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class LibraryMember {
  final String id;
  final String libraryId;
  final String userId;
  final String userEmail;
  final String role; // 'owner', 'editor', 'viewer'
  final DateTime joinedAt;

  const LibraryMember({
    required this.id,
    required this.libraryId,
    required this.userId,
    required this.userEmail,
    required this.role,
    required this.joinedAt,
  });

  factory LibraryMember.fromJson(Map<String, dynamic> json) {
    return LibraryMember(
      id: json['id'] as String,
      libraryId: json['library_id'] as String,
      userId: json['user_id'] as String,
      userEmail: json['user_email'] as String? ?? '',
      role: json['role'] as String? ?? 'editor',
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'library_id': libraryId,
        'user_id': userId,
        'user_email': userEmail,
        'role': role,
        'joined_at': joinedAt.toIso8601String(),
      };
}
