import 'skill_model.dart';
import '../core/constants/app_constants.dart';

class StaffProfileModel {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String? profileImage;
  final String specialty;
  final String licenseNumber;
  final List<String> certifications;
  final List<SkillModel> skills;
  final int yearsExperience;
  final double rating;
  final int totalJobsCompleted;
  final double reliabilityScore; // 0-100 score
  final double totalEarnings;
  final int referralCount;
  final double? currentLocationLat;
  final double? currentLocationLng;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Identity
  final String? nationalId;

  // Bank account fields
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final bool bankAccountVerified;

  /// Approval status from API: Pending | Approved | Rejected | Suspended
  final String status;
  final String? rejectionReason;

  StaffProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    this.profileImage,
    required this.specialty,
    required this.licenseNumber,
    this.certifications = const [],
    this.skills = const [],
    required this.yearsExperience,
    this.rating = 0.0,
    this.totalJobsCompleted = 0,
    this.reliabilityScore = 75.0,
    this.totalEarnings = 0.0,
    this.referralCount = 0,
    this.currentLocationLat,
    this.currentLocationLng,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
    this.nationalId,
    this.bankName,
    this.bankAccountNumber,
    this.bankAccountName,
    this.bankAccountVerified = false,
    this.status = 'Pending',
    this.rejectionReason,
  });

  List<String> get skillNames => skills.map((s) => s.name).toList();

  /// Absolute URL for NetworkImage (API may return a relative path).
  String? get resolvedProfileImageUrl {
    final img = profileImage;
    if (img == null || img.isEmpty) return null;
    if (img.startsWith('http://') || img.startsWith('https://')) return img;
    return '${AppConstants.baseUrl}$img';
  }

  List<String> get verifiedSkills =>
      skills.where((s) => s.isVerified).map((s) => s.name).toList();

  factory StaffProfileModel.fromJson(Map<String, dynamic> json) {
    T? pick<T>(String camel, String snake) {
      final value = json[camel] ?? json[snake];
      return value is T ? value : null;
    }

    List<String> pickStringList(String camel, String snake) {
      final value = json[camel] ?? json[snake];
      if (value is! List) return [];
      return value.map((e) {
        if (e is String) return e;
        if (e is Map && e['name'] != null) return e['name'].toString();
        return e.toString();
      }).toList();
    }

    List<SkillModel> pickSkills() {
      final value = json['skills'] ?? json['Skills'];
      if (value is! List) return [];
      return value.asMap().entries.map((entry) {
        final e = entry.value;
        if (e is SkillModel) return e;
        if (e is String) {
          return SkillModel(
            id: 'skill-${entry.key}',
            name: e,
            minRate: 0,
            maxRate: 0,
            yearsExperience: 0,
          );
        }
        if (e is Map) {
          final map = e.map((k, v) => MapEntry(k.toString(), v));
          final parsed = SkillModel.fromJson(map);
          if (parsed.id.isEmpty) {
            return parsed.copyWith(id: 'skill-${entry.key}');
          }
          return parsed;
        }
        return SkillModel(
          id: 'skill-${entry.key}',
          name: e.toString(),
          minRate: 0,
          maxRate: 0,
          yearsExperience: 0,
        );
      }).toList();
    }

    final now = DateTime.now();
    final parsedSkills = pickSkills();

    // Legacy verifiedSkills array — mark matching skills verified
    final legacyVerified = pickStringList('verifiedSkills', 'verified_skills');
    final skills = legacyVerified.isEmpty
        ? parsedSkills
        : parsedSkills
            .map((s) => legacyVerified.contains(s.name)
                ? s.copyWith(isVerified: true)
                : s)
            .toList();

    return StaffProfileModel(
      id: (pick<Object>('id', 'id') ?? '').toString(),
      firstName: (pick<Object>('firstName', 'first_name') ?? '').toString(),
      lastName: (pick<Object>('lastName', 'last_name') ?? '').toString(),
      email: (pick<Object>('email', 'email') ?? '').toString(),
      phone: (pick<Object>('phone', 'phone') ?? '').toString(),
      profileImage: pick<String>('profileImage', 'profile_image') ??
          pick<String>('profileImageUrl', 'profile_image_url'),
      specialty: (pick<Object>('specialty', 'specialty') ??
              pick<Object>('profession', 'profession') ??
              '')
          .toString(),
      licenseNumber:
          (pick<Object>('licenseNumber', 'license_number') ?? '').toString(),
      certifications: pickStringList('certifications', 'certifications'),
      skills: skills,
      yearsExperience:
          (pick<num>('yearsExperience', 'years_experience') ?? 0).toInt(),
      rating: (pick<num>('rating', 'rating') ?? 0).toDouble(),
      totalJobsCompleted:
          (pick<num>('totalJobsCompleted', 'total_jobs_completed') ?? 0).toInt(),
      reliabilityScore:
          (pick<num>('reliabilityScore', 'reliability_score') ?? 75).toDouble(),
      totalEarnings:
          (pick<num>('totalEarnings', 'total_earnings') ?? 0).toDouble(),
      referralCount: (pick<num>('referralCount', 'referral_count') ?? 0).toInt(),
      currentLocationLat:
          pick<num>('currentLocationLat', 'current_location_lat')?.toDouble(),
      currentLocationLng:
          pick<num>('currentLocationLng', 'current_location_lng')?.toDouble(),
      isAvailable: pick<bool>('isAvailable', 'is_available') ?? true,
      createdAt: DateTime.tryParse(
            (pick<Object>('createdAt', 'created_at') ?? '').toString(),
          ) ??
          now,
      updatedAt: DateTime.tryParse(
            (pick<Object>('updatedAt', 'updated_at') ?? '').toString(),
          ) ??
          now,
      nationalId: pick<String>('nationalId', 'national_id'),
      bankName: pick<String>('bankName', 'bank_name'),
      bankAccountNumber:
          pick<String>('bankAccountNumber', 'bank_account_number'),
      bankAccountName: pick<String>('bankAccountName', 'bank_account_name'),
      bankAccountVerified:
          pick<bool>('bankAccountVerified', 'bank_account_verified') ?? false,
      status: (pick<Object>('status', 'status') ?? 'Pending').toString(),
      rejectionReason: pick<String>('rejectionReason', 'rejection_reason'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'profile_image': profileImage,
      'specialty': specialty,
      'license_number': licenseNumber,
      'certifications': certifications,
      'skills': skills.map((s) => s.toJson()).toList(),
      'years_experience': yearsExperience,
      'rating': rating,
      'total_jobs_completed': totalJobsCompleted,
      'reliability_score': reliabilityScore,
      'total_earnings': totalEarnings,
      'referral_count': referralCount,
      'verified_skills': verifiedSkills,
      'current_location_lat': currentLocationLat,
      'current_location_lng': currentLocationLng,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'national_id': nationalId,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_account_name': bankAccountName,
      'bank_account_verified': bankAccountVerified,
      'status': status,
      'rejection_reason': rejectionReason,
    };
  }

  StaffProfileModel copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? profileImage,
    String? specialty,
    String? licenseNumber,
    List<String>? certifications,
    List<SkillModel>? skills,
    int? yearsExperience,
    double? rating,
    int? totalJobsCompleted,
    double? reliabilityScore,
    double? totalEarnings,
    int? referralCount,
    double? currentLocationLat,
    double? currentLocationLng,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? nationalId,
    String? bankName,
    String? bankAccountNumber,
    String? bankAccountName,
    bool? bankAccountVerified,
    String? status,
    String? rejectionReason,
  }) {
    return StaffProfileModel(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      specialty: specialty ?? this.specialty,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      certifications: certifications ?? this.certifications,
      skills: skills ?? this.skills,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      rating: rating ?? this.rating,
      totalJobsCompleted: totalJobsCompleted ?? this.totalJobsCompleted,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      referralCount: referralCount ?? this.referralCount,
      currentLocationLat: currentLocationLat ?? this.currentLocationLat,
      currentLocationLng: currentLocationLng ?? this.currentLocationLng,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      nationalId: nationalId ?? this.nationalId,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankAccountName: bankAccountName ?? this.bankAccountName,
      bankAccountVerified: bankAccountVerified ?? this.bankAccountVerified,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  String get fullName => '$firstName $lastName';

  bool get canApplyForJobs =>
      status.toLowerCase() == 'approved' && isAvailable;

  bool get isProfileComplete {
    return profileImage != null &&
        certifications.isNotEmpty &&
        skills.isNotEmpty;
  }
}
