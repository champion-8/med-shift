class AnnouncementModel {
  final String id;
  final String title;
  final String message;
  final String type; // 'info', 'warning', 'success', 'error'
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    required this.isActive,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    Object? pick(String camel, [String? snake]) =>
        json[camel] ?? (snake != null ? json[snake] : null);

    return AnnouncementModel(
      id: (pick('id') ?? '').toString(),
      title: (pick('title') ?? '').toString(),
      message: (pick('message') ?? '').toString(),
      type: (pick('type') ?? 'info').toString(),
      createdAt: DateTime.tryParse(
            (pick('createdAt', 'created_at') ?? '').toString(),
          ) ??
          DateTime.now(),
      expiresAt: DateTime.tryParse(
        (pick('expiresAt', 'expires_at') ?? '').toString(),
      ),
      isActive: pick('isActive', 'is_active') as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  AnnouncementModel copyWith({
    String? id,
    String? title,
    String? message,
    String? type,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
  }) {
    return AnnouncementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
    );
  }
}
