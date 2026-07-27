enum RequirementType {
  terms,
  clinicRules,
  safetyGuidelines,
  dresscode,
  parkingInfo,
  contactInfo,
  emergencyProcedure,
}

class CheckInRequirementModel {
  final String id;
  final int stepNumber;
  final String title;
  final String content;
  final RequirementType type;
  final bool requiresAcknowledgment;
  final int estimatedReadTimeSeconds;

  CheckInRequirementModel({
    required this.id,
    required this.stepNumber,
    required this.title,
    required this.content,
    required this.type,
    this.requiresAcknowledgment = true,
    this.estimatedReadTimeSeconds = 30,
  });

  factory CheckInRequirementModel.fromJson(Map<String, dynamic> json) {
    Object? pick(String camel, [String? snake]) =>
        json[camel] ?? (snake != null ? json[snake] : null);

    RequirementType parseType(Object? raw) {
      final value = (raw ?? '').toString().toLowerCase();
      return RequirementType.values.firstWhere(
        (e) => e.name.toLowerCase() == value,
        orElse: () => RequirementType.clinicRules,
      );
    }

    return CheckInRequirementModel(
      id: (pick('id') ?? '').toString(),
      stepNumber: (pick('stepNumber', 'step_number') as num?)?.toInt() ?? 0,
      title: (pick('title') ?? '').toString(),
      content: (pick('content') ?? '').toString(),
      type: parseType(pick('type')),
      requiresAcknowledgment:
          (pick('requiresAcknowledgment', 'requires_acknowledgment') as bool?) ??
              true,
      estimatedReadTimeSeconds:
          (pick('estimatedReadTimeSeconds', 'estimated_read_time_seconds')
                  as num?)
              ?.toInt() ??
          30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stepNumber': stepNumber,
      'title': title,
      'content': content,
      'type': type.name,
      'requiresAcknowledgment': requiresAcknowledgment,
      'estimatedReadTimeSeconds': estimatedReadTimeSeconds,
    };
  }
}

class CheckInSession {
  final String jobId;
  final List<CheckInRequirementModel> requirements;
  final Set<String> completedSteps;
  final DateTime startedAt;
  final DateTime? completedAt;

  CheckInSession({
    required this.jobId,
    required this.requirements,
    Set<String>? completedSteps,
    DateTime? startedAt,
    this.completedAt,
  })  : completedSteps = completedSteps ?? {},
        startedAt = startedAt ?? DateTime.now();

  bool get isCompleted =>
      requirements.isEmpty || completedSteps.length >= requirements.length;

  int get currentStep {
    for (var i = 0; i < requirements.length; i++) {
      if (!completedSteps.contains(requirements[i].id)) {
        return i;
      }
    }
    return requirements.length;
  }

  List<int> get completedStepNumbers {
    return requirements
        .where((r) => completedSteps.contains(r.id))
        .map((r) => r.stepNumber)
        .toList();
  }

  CheckInSession copyWith({
    String? jobId,
    List<CheckInRequirementModel>? requirements,
    Set<String>? completedSteps,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return CheckInSession(
      jobId: jobId ?? this.jobId,
      requirements: requirements ?? this.requirements,
      completedSteps: completedSteps ?? this.completedSteps,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
