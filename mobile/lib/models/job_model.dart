import '../core/enums/status_enums.dart';

class JobModel {
  final String id;
  final String title;
  final String description;
  final String hospitalName;
  final String hospitalAddress;
  final double latitude;
  final double longitude;
  final DateTime startTime;
  final DateTime endTime;
  final double hourlyRate;
  final double totalPay;
  final JobStatus status;
  final List<String> requiredSkills;
  final String? requiredCertification;
  final double minReliabilityScore;
  final String? clinicName;
  final String? hiredStaffId;
  final List<String> waitlistStaffIds;
  final List<String> pendingStaffIds;
  final double? staffClinicRating;
  final String? staffClinicReviewComment;
  final DateTime createdAt;
  final DateTime updatedAt;

  JobModel({
    required this.id,
    required this.title,
    required this.description,
    required this.hospitalName,
    required this.hospitalAddress,
    required this.latitude,
    required this.longitude,
    required this.startTime,
    required this.endTime,
    required this.hourlyRate,
    required this.totalPay,
    required this.status,
    required this.requiredSkills,
    this.requiredCertification,
    this.minReliabilityScore = 60.0,
    this.clinicName,
    this.hiredStaffId,
    this.waitlistStaffIds = const [],
    this.pendingStaffIds = const [],
    this.staffClinicRating,
    this.staffClinicReviewComment,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Supports MedShift API camelCase and legacy snake_case.
  factory JobModel.fromJson(Map<String, dynamic> json) {
    T? pick<T>(String camel, [String? snake]) {
      final value = json[camel] ?? (snake != null ? json[snake] : null);
      return value is T ? value : null;
    }

    Object? pickAny(String camel, [String? snake]) =>
        json[camel] ?? (snake != null ? json[snake] : null);

    List<String> pickStringList(String camel, [String? snake]) {
      final value = pickAny(camel, snake);
      if (value is! List) return [];
      return value.map((e) {
        if (e is String) return e;
        if (e is Map && e['name'] != null) return e['name'].toString();
        return e.toString();
      }).toList();
    }

    DateTime parseDate(Object? value, {DateTime? fallback}) {
      if (value == null) return fallback ?? DateTime.now();
      return DateTime.tryParse(value.toString()) ?? fallback ?? DateTime.now();
    }

    final orgName = (pickAny('organizationName', 'organization_name') ??
            pickAny('hospitalName', 'hospital_name') ??
            pickAny('clinicName', 'clinic_name') ??
            '')
        .toString();
    final locationName =
        (pickAny('locationName', 'location_name') ?? '').toString();
    final address = (pickAny('address', 'hospitalAddress') ??
            pickAny('hospital_address', 'hospitalAddress') ??
            '')
        .toString();
    final createdAt = parseDate(pickAny('createdAt', 'created_at'));
    final updatedAt =
        parseDate(pickAny('updatedAt', 'updated_at'), fallback: createdAt);

    final statusRaw = (pickAny('status') ?? 'Open').toString();

    return JobModel(
      id: (pickAny('id') ?? '').toString(),
      title: (pickAny('title') ?? '').toString(),
      description: (pickAny('description') ?? '').toString(),
      hospitalName: orgName.isNotEmpty
          ? orgName
          : (locationName.isNotEmpty ? locationName : 'Unknown'),
      hospitalAddress: address.isNotEmpty
          ? address
          : (locationName.isNotEmpty ? locationName : ''),
      latitude: (pick<num>('latitude') ?? 13.7563).toDouble(),
      longitude: (pick<num>('longitude') ?? 100.5018).toDouble(),
      startTime: parseDate(pickAny('startTime', 'start_time')),
      endTime: parseDate(pickAny('endTime', 'end_time')),
      hourlyRate: (pick<num>('hourlyRate', 'hourly_rate') ?? 0).toDouble(),
      totalPay: (pick<num>('totalPay', 'total_pay') ?? 0).toDouble(),
      status: JobStatus.fromString(statusRaw),
      requiredSkills: pickStringList('requiredSkills', 'required_skills'),
      requiredCertification:
          pickAny('requiredCertification', 'required_certification')
              ?.toString(),
      minReliabilityScore:
          (pick<num>('minReliabilityScore', 'min_reliability_score') ?? 60)
              .toDouble(),
      clinicName: orgName.isNotEmpty ? orgName : null,
      hiredStaffId: pickAny('hiredStaffProfileId', 'hired_staff_profile_id')
              ?.toString() ??
          pickAny('hiredStaffId', 'hired_staff_id')?.toString(),
      waitlistStaffIds:
          pickStringList('waitlistStaffIds', 'waitlist_staff_ids'),
      pendingStaffIds: pickStringList('pendingStaffIds', 'pending_staff_ids'),
      staffClinicRating: pick<num>('staffClinicRating', 'staff_clinic_rating')?.toDouble(),
      staffClinicReviewComment:
          pickAny('staffClinicReviewComment', 'staff_clinic_review_comment')
              ?.toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'organizationName': hospitalName,
      'hospitalName': hospitalName,
      'address': hospitalAddress,
      'hospitalAddress': hospitalAddress,
      'latitude': latitude,
      'longitude': longitude,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'hourlyRate': hourlyRate,
      'totalPay': totalPay,
      'status': status.value,
      'requiredSkills': requiredSkills,
      'requiredCertification': requiredCertification,
      'minReliabilityScore': minReliabilityScore,
      'clinicName': clinicName,
      'hiredStaffProfileId': hiredStaffId,
      'waitlistStaffIds': waitlistStaffIds,
      'pendingStaffIds': pendingStaffIds,
      'staffClinicRating': staffClinicRating,
      'staffClinicReviewComment': staffClinicReviewComment,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  JobModel copyWith({
    String? id,
    String? title,
    String? description,
    String? hospitalName,
    String? hospitalAddress,
    double? latitude,
    double? longitude,
    DateTime? startTime,
    DateTime? endTime,
    double? hourlyRate,
    double? totalPay,
    JobStatus? status,
    List<String>? requiredSkills,
    String? requiredCertification,
    double? minReliabilityScore,
    String? clinicName,
    String? hiredStaffId,
    List<String>? waitlistStaffIds,
    List<String>? pendingStaffIds,
    double? staffClinicRating,
    String? staffClinicReviewComment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      hospitalName: hospitalName ?? this.hospitalName,
      hospitalAddress: hospitalAddress ?? this.hospitalAddress,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      totalPay: totalPay ?? this.totalPay,
      status: status ?? this.status,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      requiredCertification: requiredCertification ?? this.requiredCertification,
      minReliabilityScore: minReliabilityScore ?? this.minReliabilityScore,
      clinicName: clinicName ?? this.clinicName,
      hiredStaffId: hiredStaffId ?? this.hiredStaffId,
      waitlistStaffIds: waitlistStaffIds ?? this.waitlistStaffIds,
      pendingStaffIds: pendingStaffIds ?? this.pendingStaffIds,
      staffClinicRating: staffClinicRating ?? this.staffClinicRating,
      staffClinicReviewComment:
          staffClinicReviewComment ?? this.staffClinicReviewComment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  String get displayName => clinicName ?? hospitalName;

  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  bool get isAvailable {
    return status == JobStatus.open && startTime.isAfter(DateTime.now());
  }

  bool get isWaitlistFull {
    return waitlistStaffIds.length >= 10;
  }

  bool get isPendingFull {
    return pendingStaffIds.length >= 10;
  }
}
