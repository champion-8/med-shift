enum NotificationType {
  newJob,
  jobReminder,
  checkInReminder,
  jobCancelled,
  jobUpdated,
  waitlistPromoted,
  paymentReceived,
  other,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final String? jobId;
  final Map<String, dynamic>? metadata;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.jobId,
    this.metadata,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    Object? pick(String camel, [String? snake]) =>
        json[camel] ?? (snake != null ? json[snake] : null);

    NotificationType parseType(Object? raw) {
      final value = (raw ?? '').toString().toLowerCase();
      return switch (value) {
        'newjob' => NotificationType.newJob,
        'jobreminder' => NotificationType.jobReminder,
        'checkinreminder' => NotificationType.checkInReminder,
        'waitlistpromoted' => NotificationType.waitlistPromoted,
        'paymentreceived' => NotificationType.paymentReceived,
        'jobcancelled' => NotificationType.jobCancelled,
        'applicationupdate' || 'jobupdated' => NotificationType.jobUpdated,
        _ => NotificationType.other,
      };
    }

    return NotificationModel(
      id: (pick('id') ?? '').toString(),
      title: (pick('title') ?? '').toString(),
      message: (pick('message') ?? '').toString(),
      type: parseType(pick('type')),
      createdAt: DateTime.tryParse(
            (pick('createdAt', 'created_at') ?? '').toString(),
          ) ??
          DateTime.now(),
      isRead: pick('isRead', 'is_read') == true,
      jobId: pick('jobId', 'job_id')?.toString(),
      metadata: pick('metadata') is Map
          ? Map<String, dynamic>.from(pick('metadata') as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'type': type.name,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      'jobId': jobId,
      'metadata': metadata,
    };
  }

  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    String? jobId,
    Map<String, dynamic>? metadata,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      jobId: jobId ?? this.jobId,
      metadata: metadata ?? this.metadata,
    );
  }
}
