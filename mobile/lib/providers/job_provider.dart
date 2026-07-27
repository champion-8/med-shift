import 'package:flutter/foundation.dart';
import '../models/job_model.dart';
import '../core/enums/status_enums.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_constants.dart';
import '../utils/conflict_checker.dart';

class JobProvider with ChangeNotifier {
  final ApiClient _apiClient;

  List<JobModel> _allJobs = [];
  List<JobModel> _myHiredJobs = [];
  List<JobModel> _myWaitlistJobs = [];
  List<JobModel> _myPendingJobs = [];
  bool _isLoading = false;
  String? _error;

  JobProvider(this._apiClient);

  // Getters
  List<JobModel> get allJobs => _allJobs;
  List<JobModel> get myHiredJobs => _myHiredJobs;
  List<JobModel> get myWaitlistJobs => _myWaitlistJobs;
  List<JobModel> get myPendingJobs => _myPendingJobs;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Get available jobs (open for applications)
  List<JobModel> get availableJobs {
    return _allJobs
        .where((job) =>
            job.status == JobStatus.open ||
            job.status == JobStatus.applied ||
            job.status == JobStatus.selecting)
        .toList();
  }

  // Get jobs by status
  List<JobModel> getJobsByStatus(JobStatus status) {
    return _allJobs.where((job) => job.status == status).toList();
  }

  Future<void> _refreshJobLists(String? staffId) async {
    await _fetchJobsSilent();
    await _fetchMyJobsSilent('pending', (jobs) => _myPendingJobs = jobs);
    await _fetchMyJobsSilent('hired', (jobs) => _myHiredJobs = jobs);
    await _fetchMyJobsSilent('waitlist', (jobs) => _myWaitlistJobs = jobs);
    notifyListeners();
  }

  Future<void> _fetchJobsSilent() async {
    if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
      _allJobs = _generateMockJobs();
      return;
    }
    final response = await _apiClient.get('${AppConstants.staffApiPrefix}/jobs');
    if (response.statusCode == 200) {
      final List<dynamic> jobsJson =
          response.data is List ? response.data as List : (response.data['jobs'] ?? []);
      _allJobs = jobsJson
          .map((json) => JobModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    }
  }

  Future<void> _fetchMyJobsSilent(
    String filter,
    void Function(List<JobModel>) assign,
  ) async {
    if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) return;
    final response = await _apiClient.get(
      '${AppConstants.staffApiPrefix}/my-jobs',
      queryParameters: {'filter': filter},
    );
    if (response.statusCode == 200) {
      final List<dynamic> jobsJson =
          response.data is List ? response.data as List : (response.data['jobs'] ?? []);
      assign(jobsJson
          .map((json) => JobModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList());
    }
  }

  /// Fetch all available jobs from API
  Future<void> fetchJobs() async {
    _setLoading(true);
    _error = null;

    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Loading mock jobs');
        await Future.delayed(const Duration(milliseconds: 500));
        
        _allJobs = _generateMockJobs();
        notifyListeners();
        _setLoading(false);
        return;
      }
      // ===================================================

      final response = await _apiClient.get('${AppConstants.staffApiPrefix}/jobs');

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson =
            response.data is List ? response.data as List : (response.data['jobs'] ?? []);
        _allJobs = jobsJson
            .map((json) => JobModel.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();

        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error fetching jobs: ${e.message}');
    } catch (e) {
      _error = 'Failed to load jobs';
      debugPrint('Error fetching jobs: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch jobs hired by current staff
  Future<void> fetchMyHiredJobs(String staffId) async {
    _setLoading(true);
    _error = null;

    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Loading mock hired jobs');
        await Future.delayed(const Duration(milliseconds: 300));
        
        _myHiredJobs = _generateMockHiredJobs();
        notifyListeners();
        _setLoading(false);
        return;
      }
      // ===================================================

      final response = await _apiClient.get(
        '${AppConstants.staffApiPrefix}/my-jobs',
        queryParameters: {'filter': 'hired'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson =
            response.data is List ? response.data as List : (response.data['jobs'] ?? []);
        _myHiredJobs = jobsJson
            .map((json) => JobModel.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();

        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error fetching hired jobs: ${e.message}');
    } catch (e) {
      _error = 'Failed to load hired jobs';
      debugPrint('Error fetching hired jobs: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch jobs where staff is on waitlist
  Future<void> fetchMyWaitlistJobs(String staffId) async {
    _setLoading(true);
    _error = null;

    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Loading mock waitlist jobs');
        await Future.delayed(const Duration(milliseconds: 300));
        
        _myWaitlistJobs = _generateMockWaitlistJobs();
        notifyListeners();
        _setLoading(false);
        return;
      }
      // ===================================================

      final response = await _apiClient.get(
        '${AppConstants.staffApiPrefix}/my-jobs',
        queryParameters: {'filter': 'waitlist'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson =
            response.data is List ? response.data as List : (response.data['jobs'] ?? []);
        _myWaitlistJobs = jobsJson
            .map((json) => JobModel.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();

        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error fetching waitlist jobs: ${e.message}');
    } catch (e) {
      _error = 'Failed to load waitlist jobs';
      debugPrint('Error fetching waitlist jobs: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch jobs that staff applied for but clinic hasn't accepted yet (Pending applications)
  Future<void> fetchMyPendingJobs(String staffId) async {
    _setLoading(true);
    _error = null;

    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Loading mock pending jobs');
        await Future.delayed(const Duration(milliseconds: 300));
        
        _myPendingJobs = _generateMockPendingJobs();
        notifyListeners();
        _setLoading(false);
        return;
      }
      // ===================================================

      final response = await _apiClient.get(
        '${AppConstants.staffApiPrefix}/my-jobs',
        queryParameters: {'filter': 'pending'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jobsJson =
            response.data is List ? response.data as List : (response.data['jobs'] ?? []);
        _myPendingJobs = jobsJson
            .map((json) => JobModel.fromJson(Map<String, dynamic>.from(json as Map)))
            .toList();

        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error fetching pending jobs: ${e.message}');
    } catch (e) {
      _error = 'Failed to load pending jobs';
      debugPrint('Error fetching pending jobs: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Apply for a job (with conflict checking).
  /// [staffId] is optional — API identifies staff from JWT.
  Future<bool> applyForJob({
    required String jobId,
    String? staffId,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      JobModel? job;
      try {
        job = _allJobs.firstWhere((j) => j.id == jobId);
      } catch (_) {
        job = null;
      }

      if (job != null &&
          ConflictChecker.hasTimeConflict(
            newJob: job,
            hiredJobs: _myHiredJobs,
          )) {
        final conflicts = ConflictChecker.getConflictingJobs(
          newJob: job,
          hiredJobs: _myHiredJobs,
        );
        _error = ConflictChecker.getConflictMessage(conflicts);
        _setLoading(false);
        return false;
      }

      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/apply',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _refreshJobLists(staffId);
        return true;
      }

      _error = 'Failed to apply for job';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error applying for job: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Failed to apply for job';
      debugPrint('Error applying for job: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Start work after check-in (CheckedIn → InProgress).
  Future<bool> startWork({required String jobId, String? staffId}) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/start',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _refreshJobLists(staffId);
        return true;
      }

      _error = 'Failed to start work';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error starting work: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Failed to start work';
      debugPrint('Error starting work: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Complete work after start (InProgress → Completed + pay).
  Future<bool> completeWork({required String jobId, String? staffId}) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/complete',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _refreshJobLists(staffId);
        return true;
      }

      _error = 'Failed to complete work';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error completing work: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Failed to complete work';
      debugPrint('Error completing work: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Staff rates the clinic after job completion.
  Future<bool> rateClinic({
    required String jobId,
    required int rating,
    String? comment,
    String? staffId,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/rate-clinic',
        data: {
          'rating': rating,
          if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await _refreshJobLists(staffId);
        return true;
      }

      _error = 'Failed to rate clinic';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error rating clinic: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Failed to rate clinic';
      debugPrint('Error rating clinic: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Report an on-site issue for a hired job (CheckedIn / InProgress).
  Future<bool> reportJobIssue({
    required String jobId,
    required String category,
    required String description,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/issues',
        data: {
          'category': category,
          'description': description,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }

      _error = 'Failed to report issue';
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error reporting issue: ${e.message}');
      return false;
    } catch (e) {
      _error = 'Failed to report issue';
      debugPrint('Error reporting issue: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cancel a hired job (will trigger penalty in wallet and promote waitlist)
  Future<Map<String, dynamic>> cancelHiredJob({
    required String jobId,
    required String staffId,
    String? reason,
    Function(String promotedStaffId, String jobId, String jobTitle)? onWaitlistPromoted,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // Calculate penalty based on time until job start
      final job = _myHiredJobs.firstWhere((j) => j.id == jobId);
      final hoursUntilStart = job.startTime.difference(DateTime.now()).inHours;
      
      double penaltyAmount = 0;
      if (hoursUntilStart < 24) {
        penaltyAmount = 100.0; // 100 บาท ถ้ายกเลิกน้อยกว่า 24 ชั่วโมง
      } else if (hoursUntilStart < 48) {
        penaltyAmount = 50.0; // 50 บาท ถ้ายกเลิกน้อยกว่า 48 ชั่วโมง
      }
      // ถ้ามากกว่า 48 ชั่วโมง ไม่มีค่าปรับ

      String? promotedStaffId;

      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Cancelling job');
        await Future.delayed(const Duration(milliseconds: 500));

        // Remove from hired jobs
        _myHiredJobs.removeWhere((j) => j.id == jobId);
        
        // Check if there are people in waitlist and promote the first one
        if (job.waitlistStaffIds.isNotEmpty) {
          promotedStaffId = job.waitlistStaffIds.first;
          
          debugPrint('🚀 BYPASS API: Promoting staff from waitlist: $promotedStaffId');
          
          // If the promoted staff is the current user, move from waitlist to hired
          if (promotedStaffId == staffId) {
            final waitlistJob = _myWaitlistJobs.firstWhere(
              (j) => j.id == jobId,
              orElse: () => job,
            );
            _myWaitlistJobs.removeWhere((j) => j.id == jobId);
            _myHiredJobs.add(waitlistJob.copyWith(
              hiredStaffId: promotedStaffId,
              waitlistStaffIds: waitlistJob.waitlistStaffIds
                  .where((id) => id != promotedStaffId)
                  .toList(),
            ));
          }
          
          // Call callback to create notification
          if (onWaitlistPromoted != null) {
            onWaitlistPromoted(promotedStaffId, jobId, job.title);
          }
        }
        
        notifyListeners();
        _setLoading(false);
        
        return {
          'success': true,
          'penalty_amount': penaltyAmount,
          'hours_until_start': hoursUntilStart,
          'promoted_staff_id': promotedStaffId,
        };
      }
      // ===================================================

      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/cancel',
        data: {
          'reason': reason,
        },
      );

      if (response.statusCode == 200) {
        promotedStaffId = response.data['promoted_staff_id'] as String?;
        
        // If someone was promoted and it's the current user, update their lists
        if (promotedStaffId != null && promotedStaffId == staffId && onWaitlistPromoted != null) {
          onWaitlistPromoted(promotedStaffId, jobId, job.title);
        }
        
        // Refresh data
        await fetchMyHiredJobs(staffId);
        await fetchJobs();
        _setLoading(false);
        
        return {
          'success': true,
          'penalty_amount': response.data['penalty_amount'] ?? penaltyAmount,
          'hours_until_start': hoursUntilStart,
          'promoted_staff_id': promotedStaffId,
        };
      }

      _setLoading(false);
      return {'success': false, 'penalty_amount': 0};
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error cancelling job: ${e.message}');
      _setLoading(false);
      return {'success': false, 'penalty_amount': 0};
    } catch (e) {
      _error = 'Failed to cancel job';
      debugPrint('Error cancelling job: $e');
      _setLoading(false);
      return {'success': false, 'penalty_amount': 0};
    }
  }

  /// Withdraw from waitlist
  Future<bool> withdrawFromWaitlist({
    required String jobId,
    required String staffId,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Withdrawing from waitlist');
        await Future.delayed(const Duration(milliseconds: 300));

        // Remove from waitlist jobs
        _myWaitlistJobs.removeWhere((j) => j.id == jobId);
        
        notifyListeners();
        _setLoading(false);
        return true;
      }
      // ===================================================

      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/withdraw',
      );

      if (response.statusCode == 200) {
        await fetchMyWaitlistJobs(staffId);
        await fetchJobs();
        _setLoading(false);
        return true;
      }

      _setLoading(false);
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error withdrawing from waitlist: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to withdraw from waitlist';
      debugPrint('Error withdrawing: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Get job by ID (searches hired/waitlist/pending/open lists)
  JobModel? getJobById(String jobId) {
    for (final list in [_myHiredJobs, _myWaitlistJobs, _myPendingJobs, _allJobs]) {
      for (final job in list) {
        if (job.id == jobId) return job;
      }
    }
    return null;
  }

  bool isHiredJob(String jobId) => _myHiredJobs.any((j) => j.id == jobId);
  bool isWaitlistJob(String jobId) => _myWaitlistJobs.any((j) => j.id == jobId);
  bool isPendingJob(String jobId) => _myPendingJobs.any((j) => j.id == jobId);

  /// Filter jobs by criteria. Upper rate bound is not applied (minimum-only).
  List<JobModel> filterJobs({
    List<String>? skills,
    double? minRate,
    double? maxRate, // ignored — staff rate is minimum desired only
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _allJobs.where((job) {
      // Filter by skills
      if (skills != null && skills.isNotEmpty) {
        final hasRequiredSkill = job.requiredSkills.any(
          (skill) => skills.contains(skill),
        );
        if (!hasRequiredSkill) return false;
      }

      // Filter by minimum rate only (no upper ceiling)
      if (minRate != null && job.hourlyRate < minRate) return false;

      // Filter by date
      if (startDate != null && job.startTime.isBefore(startDate)) return false;
      if (endDate != null && job.startTime.isAfter(endDate)) return false;

      return true;
    }).toList();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ========== MOCK DATA GENERATORS (Development) ==========
  
  List<JobModel> _generateMockJobs() {
    final now = DateTime.now();
    return [
      JobModel(
        id: 'job-001',
        title: 'พยาบาลดูแลผู้สูงอายุ - กะเช้า',
        description: 'ดูแลผู้สูงอายุที่บ้าน วัดสัญญาณชีพ ให้ยา และช่วยเหลือกิจกรรมประจำวัน',
        hospitalName: 'โรงพยาบาลเจ้าพระยา',
        hospitalAddress: '113 ถ.เตชะวณิช แขวงอรุณอมรินทร์ เขตบางกอกน้อย กรุงเทพฯ 10700',
        latitude: 13.7465,
        longitude: 100.4876,
        startTime: now.add(const Duration(days: 2, hours: 8)),
        endTime: now.add(const Duration(days: 2, hours: 16)),
        hourlyRate: 350.0,
        totalPay: 2800.0,
        status: JobStatus.open,
        requiredSkills: ['การดูแลผู้สูงอายุ', 'วัดสัญญาณชีพ'],
        requiredCertification: 'BLS',
        minReliabilityScore: 70.0,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 2)),
      ),
      JobModel(
        id: 'job-002',
        title: 'พยาบาลฉีดยา - คลินิกเอกชน',
        description: 'ให้บริการฉีดยา วัคซีน และเจาะเลือดที่คลินิก',
        hospitalName: 'คลินิกเวชกรรมสุขใจ',
        hospitalAddress: '25/10 ถ.พระราม 4 แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110',
        latitude: 13.7222,
        longitude: 100.5629,
        startTime: now.add(const Duration(days: 1, hours: 9)),
        endTime: now.add(const Duration(days: 1, hours: 18)),
        hourlyRate: 400.0,
        totalPay: 3600.0,
        status: JobStatus.open,
        requiredSkills: ['ฉีดยา', 'เจาะเลือด'],
        minReliabilityScore: 75.0,
        clinicName: 'คลินิกเวชกรรมสุขใจ',
        createdAt: now.subtract(const Duration(hours: 12)),
        updatedAt: now.subtract(const Duration(hours: 5)),
      ),
      JobModel(
        id: 'job-003',
        title: 'พยาบาลดูแลผู้ป่วยโควิด - กะดึก',
        description: 'ดูแลผู้ป่วยโควิด-19 ที่โรงพยาบาลสนาม ต้องมีประสบการณ์',
        hospitalName: 'โรงพยาบาลศิริราช',
        hospitalAddress: '2 ถ.วังหลัง แขวงศิริราช เขตบางกอกน้อย กรุงเทพฯ 10700',
        latitude: 13.7588,
        longitude: 100.4838,
        startTime: now.add(const Duration(days: 3, hours: 20)),
        endTime: now.add(const Duration(days: 4, hours: 8)),
        hourlyRate: 500.0,
        totalPay: 6000.0,
        status: JobStatus.open,
        requiredSkills: ['การดูแลผู้ป่วยหนัก', 'Infection Control'],
        requiredCertification: 'ACLS',
        minReliabilityScore: 85.0,
        createdAt: now.subtract(const Duration(hours: 6)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
      JobModel(
        id: 'job-004',
        title: 'พยาบาลดูแลเด็ก - รพ.เอกชน',
        description: 'ดูแลเด็กป่วยในโรงพยาบาล ฝึกอบรมพิเศษ',
        hospitalName: 'โรงพยาบาลสมิติเวช',
        hospitalAddress: '133 ถ.สุขุมวิท 49 แขวงคลองตันเหนือ เขตวัฒนา กรุงเทพฯ 10110',
        latitude: 13.7365,
        longitude: 100.5747,
        startTime: now.add(const Duration(days: 5, hours: 7)),
        endTime: now.add(const Duration(days: 5, hours: 19)),
        hourlyRate: 450.0,
        totalPay: 5400.0,
        status: JobStatus.open,
        requiredSkills: ['Pediatric Care', 'การดูแลเด็ก'],
        minReliabilityScore: 80.0,
        createdAt: now.subtract(const Duration(hours: 3)),
        updatedAt: now.subtract(const Duration(minutes: 30)),
      ),
      JobModel(
        id: 'job-005',
        title: 'พยาบาลตรวจสุขภาพ - งาน Event',
        description: 'ตรวจสุขภาพเบื้องต้นในงานวิ่งมาราธอน พร้อมปฐมพยาบาล',
        hospitalName: 'มูลนิธิกีฬามาราธอน',
        hospitalAddress: 'สนามกีฬาแห่งชาติ ถ.พระราม 1 เขตปทุมวัน กรุงเทพฯ 10330',
        latitude: 13.7475,
        longitude: 100.5329,
        startTime: now.add(const Duration(days: 7, hours: 5)),
        endTime: now.add(const Duration(days: 7, hours: 14)),
        hourlyRate: 300.0,
        totalPay: 2700.0,
        status: JobStatus.open,
        requiredSkills: ['ปฐมพยาบาล', 'CPR'],
        requiredCertification: 'BLS',
        minReliabilityScore: 60.0,
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 10)),
      ),
    ];
  }

  List<JobModel> _generateMockHiredJobs() {
    final now = DateTime.now();
    return [
      // งานวันนี้ - สำหรับทดสอบ check-in
      JobModel(
        id: 'job-hired-today',
        title: 'พยาบาลตรวจสุขภาพ - บริษัทเอกชน',
        description: 'ตรวจสุขภาพประจำปีสำหรับพนักงาน',
        hospitalName: 'บริษัท ABC จำกัด (สำนักงานใหญ่)',
        hospitalAddress: '999 ถ.พระราม 4 แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110',
        latitude: 13.7236,
        longitude: 100.5632,
        startTime: DateTime(now.year, now.month, now.day, 9, 0), // วันนี้ 09:00
        endTime: DateTime(now.year, now.month, now.day, 17, 0), // วันนี้ 17:00
        hourlyRate: 400.0,
        totalPay: 3200.0,
        status: JobStatus.confirmed,
        requiredSkills: ['การตรวจสุขภาพ', 'วัดความดัน'],
        minReliabilityScore: 70.0,
        hiredStaffId: AppConstants.mockUserId,
        waitlistStaffIds: [],
        pendingStaffIds: [],
        createdAt: now.subtract(const Duration(days: 7)),
        updatedAt: now.subtract(const Duration(days: 5)),
      ),
      JobModel(
        id: 'job-hired-001',
        title: 'พยาบาลประจำคลินิก - กะเช้า',
        description: 'ให้บริการพยาบาลประจำคลินิกทั่วไป',
        hospitalName: 'คลินิกหมอครอบครัว',
        hospitalAddress: '50/2 ถ.รัชดาภิเษก แขวงลาดยาว เขตจตุจักร กรุงเทพฯ 10900',
        latitude: 13.7894,
        longitude: 100.5622,
        startTime: now.add(const Duration(days: 1, hours: 8)),
        endTime: now.add(const Duration(days: 1, hours: 17)),
        hourlyRate: 380.0,
        totalPay: 3420.0,
        status: JobStatus.confirmed,
        requiredSkills: ['การพยาบาลทั่วไป'],
        minReliabilityScore: 70.0,
        hiredStaffId: AppConstants.mockUserId,
        waitlistStaffIds: ['staff-002', 'staff-003'], // มีคนรอ 2 คน
        pendingStaffIds: [],
        createdAt: now.subtract(const Duration(days: 3)),
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      JobModel(
        id: 'job-hired-002',
        title: 'พยาบาลฉีดวัคซีน - โรงเรียน',
        description: 'ฉีดวัคซีนให้นักเรียนในโรงเรียน',
        hospitalName: 'โรงเรียนสาธิตแห่งจุฬาฯ',
        hospitalAddress: '10 ถ.พญาไท แขวงวังใหม่ เขตปทุมวัน กรุงเทพฯ 10330',
        latitude: 13.7477,
        longitude: 100.5331,
        startTime: now.add(const Duration(days: 3, hours: 9)),
        endTime: now.add(const Duration(days: 3, hours: 15)),
        hourlyRate: 400.0,
        totalPay: 2400.0,
        status: JobStatus.confirmed,
        requiredSkills: ['ฉีดยา', 'การดูแลเด็ก'],
        minReliabilityScore: 75.0,
        hiredStaffId: AppConstants.mockUserId,
        waitlistStaffIds: ['staff-004'], // มีคนรออยู่ 1 คน
        pendingStaffIds: [],
        createdAt: now.subtract(const Duration(days: 4)),
        updatedAt: now.subtract(const Duration(days: 3)),
      ),
    ];
  }

  List<JobModel> _generateMockWaitlistJobs() {
    final now = DateTime.now();
    return [
      JobModel(
        id: 'job-wait-001',
        title: 'พยาบาล ICU - โรงพยาบาลใหญ่',
        description: 'ดูแลผู้ป่วยหนักในหอผู้ป่วยวิกฤต',
        hospitalName: 'โรงพยาบาลจุฬาลงกรณ์',
        hospitalAddress: '1873 ถ.พระราม 4 แขวงปทุมวัน เขตปทุมวัน กรุงเทพฯ 10330',
        latitude: 13.7337,
        longitude: 100.5297,
        startTime: now.add(const Duration(days: 4, hours: 8)),
        endTime: now.add(const Duration(days: 4, hours: 20)),
        hourlyRate: 550.0,
        totalPay: 6600.0,
        status: JobStatus.selecting,
        requiredSkills: ['ICU', 'Ventilator Care'],
        requiredCertification: 'ACLS',
        minReliabilityScore: 90.0,
        waitlistStaffIds: [AppConstants.mockUserId, 'staff-002', 'staff-003'],
        pendingStaffIds: [],
        hiredStaffId: 'staff-other',
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now.subtract(const Duration(hours: 8)),
      ),
      JobModel(
        id: 'job-wait-002',
        title: 'พยาบาลดูแลผู้ป่วยโควิด - กะดึก',
        description: 'ดูแลผู้ป่วยโควิด-19 ที่โรงพยาบาลสนาม',
        hospitalName: 'โรงพยาบาลศิริราช',
        hospitalAddress: '2 ถ.วังหลัง แขวงศิริราช เขตบางกอกน้อย กรุงเทพฯ 10700',
        latitude: 13.7588,
        longitude: 100.4838,
        startTime: now.add(const Duration(days: 6, hours: 20)),
        endTime: now.add(const Duration(days: 7, hours: 8)),
        hourlyRate: 500.0,
        totalPay: 6000.0,
        status: JobStatus.selecting,
        requiredSkills: ['การดูแลผู้ป่วยหนัก', 'Infection Control'],
        requiredCertification: 'ACLS',
        minReliabilityScore: 85.0,
        waitlistStaffIds: ['staff-005', AppConstants.mockUserId],
        pendingStaffIds: [],
        hiredStaffId: 'staff-main-001',
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 4)),
      ),
    ];
  }

  List<JobModel> _generateMockPendingJobs() {
    final now = DateTime.now();
    return [
      JobModel(
        id: 'job-pending-001',
        title: 'พยาบาลดูแลผู้สูงอายุ - คลินิกเอกชน',
        description: 'ดูแลผู้สูงอายุที่คลินิก ตรวจวัดความดัน น้ำตาลในเลือด',
        hospitalName: 'คลินิกแก้วมณี',
        hospitalAddress: '123 ถ.สุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110',
        latitude: 13.7200,
        longitude: 100.5700,
        startTime: now.add(const Duration(days: 5, hours: 9)),
        endTime: now.add(const Duration(days: 5, hours: 17)),
        hourlyRate: 350.0,
        totalPay: 2800.0,
        status: JobStatus.selecting,
        requiredSkills: ['การดูแลผู้สูงอายุ', 'ตรวจวัดสัญญาณชีพ'],
        minReliabilityScore: 75.0,
        waitlistStaffIds: [],
        pendingStaffIds: [AppConstants.mockUserId, 'staff-006', 'staff-007'],
        createdAt: now.subtract(const Duration(hours: 12)),
        updatedAt: now.subtract(const Duration(hours: 6)),
      ),
      JobModel(
        id: 'job-pending-002',
        title: 'พยาบาลฉีดวัคซีน - โรงพยาบาลชุมชน',
        description: 'ฉีดวัคซีนป้องกันโรคให้ประชาชน',
        hospitalName: 'โรงพยาบาลบางนา',
        hospitalAddress: '98 ถ.บางนา-ตราด แขวงบางนา เขตบางนา กรุงเทพฯ 10260',
        latitude: 13.6683,
        longitude: 100.6056,
        startTime: now.add(const Duration(days: 8, hours: 8)),
        endTime: now.add(const Duration(days: 8, hours: 16)),
        hourlyRate: 4000.0,
        totalPay: 32000.0,
        status: JobStatus.selecting,
        requiredSkills: ['ฉีดยา', 'การบริการประชาชน'],
        minReliabilityScore: 70.0,
        waitlistStaffIds: [],
        pendingStaffIds: [AppConstants.mockUserId, 'staff-008'],
        createdAt: now.subtract(const Duration(days: 1)),
        updatedAt: now.subtract(const Duration(hours: 10)),
      ),
    ];
  }
}
