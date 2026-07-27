/// Model for individual skill/procedure with rate and experience
class SkillModel {
  final String id;
  final String name;
  final double minRate; // THB per hour
  final double maxRate; // THB per hour — kept for API compat; mirrored from minRate
  final int yearsExperience;
  final bool isVerified;
  final String? certification;

  SkillModel({
    required this.id,
    required this.name,
    required this.minRate,
    required this.maxRate,
    required this.yearsExperience,
    this.isVerified = false,
    this.certification,
  });

  factory SkillModel.fromJson(Map<String, dynamic> json) {
    Object? pick(String camel, [String? snake]) =>
        json[camel] ?? (snake != null ? json[snake] : null);

    return SkillModel(
      id: (pick('id') ?? '').toString(),
      name: (pick('name') ?? '').toString(),
      minRate: (pick('minRate', 'min_rate') as num?)?.toDouble() ?? 0,
      maxRate: (pick('maxRate', 'max_rate') as num?)?.toDouble() ?? 0,
      yearsExperience:
          (pick('yearsExperience', 'years_experience') as num?)?.toInt() ?? 0,
      isVerified: (pick('isVerified', 'is_verified') as bool?) ?? false,
      certification: pick('certification') as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'minRate': minRate,
      'maxRate': maxRate,
      'yearsExperience': yearsExperience,
      'isVerified': isVerified,
      'certification': certification,
    };
  }

  /// Payload for PUT /api/staff/profile
  /// MaxRate is kept for API compatibility and mirrored from MinRate.
  Map<String, dynamic> toUpsertJson() {
    final rate = minRate > 0 ? minRate : maxRate;
    return {
      'name': name,
      'minRate': rate,
      'maxRate': rate,
      'yearsExperience': yearsExperience,
      'certification': certification,
    };
  }

  SkillModel copyWith({
    String? id,
    String? name,
    double? minRate,
    double? maxRate,
    int? yearsExperience,
    bool? isVerified,
    String? certification,
  }) {
    return SkillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      minRate: minRate ?? this.minRate,
      maxRate: maxRate ?? this.maxRate,
      yearsExperience: yearsExperience ?? this.yearsExperience,
      isVerified: isVerified ?? this.isVerified,
      certification: certification ?? this.certification,
    );
  }

  double get effectiveMinRate => minRate > 0 ? minRate : maxRate;

  /// Localized minimum rate label. Pass [tr] / [trParams] from AppLocalizations.
  String rateLabel(
    String Function(String key) tr, {
    String Function(String key, Map<String, String> params)? trParams,
  }) {
    final rate = effectiveMinRate;
    if (rate <= 0) return tr('skill_rate_unset');
    final params = trParams ?? (k, p) {
      var s = tr(k);
      p.forEach((key, value) => s = s.replaceAll('{$key}', value));
      return s;
    };
    return params('skill_min_rate_display', {'rate': rate.toInt().toString()});
  }

  String experienceLabel(
    String Function(String key) tr, {
    String Function(String key, Map<String, String> params)? trParams,
  }) {
    final params = trParams ?? (k, p) {
      var s = tr(k);
      p.forEach((key, value) => s = s.replaceAll('{$key}', value));
      return s;
    };
    if (yearsExperience == 0) return tr('skill_exp_lt1');
    if (yearsExperience == 1) return tr('skill_exp_1');
    return params('skill_exp_n', {'n': yearsExperience.toString()});
  }

  @Deprecated('Use rateLabel() with l10n')
  String get rateRange {
    final rate = effectiveMinRate;
    if (rate <= 0) return 'ยังไม่ตั้งอัตรา';
    return 'ขั้นต่ำ ฿${rate.toInt()}/ชม.';
  }

  @Deprecated('Use experienceLabel() with l10n')
  String get experienceText {
    if (yearsExperience == 0) return 'น้อยกว่า 1 ปี';
    if (yearsExperience == 1) return '1 ปี';
    return '$yearsExperience ปี';
  }
}
