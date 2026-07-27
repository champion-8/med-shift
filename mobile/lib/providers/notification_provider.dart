import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../models/announcement_model.dart';
import '../models/check_in_requirement_model.dart';
import '../core/api/api_client.dart';
import '../core/constants/app_constants.dart';

class NotificationProvider with ChangeNotifier {
  final ApiClient _apiClient;

  List<NotificationModel> _notifications = [];
  CheckInSession? _currentCheckInSession;
  bool _isLoading = false;
  String? _error;

  NotificationProvider(this._apiClient);

  // Getters
  List<NotificationModel> get notifications => _notifications;
  CheckInSession? get currentCheckInSession => _currentCheckInSession;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  List<NotificationModel> get unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  /// Fetch all notifications for staff
  Future<void> fetchNotifications(String staffId) async {
    _setLoading(true);
    _error = null;

    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Loading mock notifications');
        await Future.delayed(const Duration(milliseconds: 400));

        _notifications = _generateMockNotifications();
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
        _setLoading(false);
        return;
      }
      // ===================================================

      final response = await _apiClient.get('${AppConstants.staffApiPrefix}/notifications');

      if (response.statusCode == 200) {
        final List<dynamic> notificationsJson =
            response.data is List
                ? response.data as List
                : (response.data['notifications'] ?? []);
        _notifications = notificationsJson
            .whereType<Map>()
            .map((json) =>
                NotificationModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();

        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error fetching notifications: ${e.message}');
    } catch (e) {
      _error = 'Failed to load notifications';
      debugPrint('Error fetching notifications: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Marking notification as read');
        await Future.delayed(const Duration(milliseconds: 200));

        final index =
            _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] =
              _notifications[index].copyWith(isRead: true);
          notifyListeners();
          return true;
        }
        return false;
      }
      // ===================================================

      final response = await _apiClient.patch(
        '${AppConstants.staffApiPrefix}/notifications/$notificationId/read',
      );

      if (response.statusCode == 200) {
        final index =
            _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          _notifications[index] =
              _notifications[index].copyWith(isRead: true);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read (loops PATCH read — no bulk API yet)
  Future<bool> markAllAsRead(String staffId) async {
    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Marking all notifications as read');
        await Future.delayed(const Duration(milliseconds: 300));

        _notifications = _notifications
            .map((n) => n.copyWith(isRead: true))
            .toList();
        notifyListeners();
        return true;
      }

      final unread = _notifications.where((n) => !n.isRead).toList();
      for (final n in unread) {
        await markAsRead(n.id);
      }
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Server creates these; client just refreshes when not in bypass mode.
  Future<void> createWaitlistPromotionNotification({
    required String staffId,
    required String jobId,
    required String jobTitle,
  }) async {
    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Creating waitlist promotion notification');

        final notification = NotificationModel(
          id: 'notif-promotion-${DateTime.now().millisecondsSinceEpoch}',
          title: 'ยินดีด้วย! คุณได้รับงานแล้ว',
          message:
              'คุณได้รับการเลือกจากรายการสำรองสำหรับงาน "$jobTitle" กรุณาเช็คอินก่อนเข้างาน',
          type: NotificationType.waitlistPromoted,
          createdAt: DateTime.now(),
          isRead: false,
          jobId: jobId,
        );

        _notifications.insert(0, notification);
        notifyListeners();
        return;
      }

      await fetchNotifications(staffId);
    } catch (e) {
      debugPrint('Error refreshing after waitlist promotion: $e');
    }
  }

  /// Server creates these; client just refreshes when not in bypass mode.
  Future<void> createNewJobNotification({
    required String staffId,
    required String jobId,
    required String jobTitle,
  }) async {
    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Creating new job notification');

        final notification = NotificationModel(
          id: 'notif-newjob-${DateTime.now().millisecondsSinceEpoch}',
          title: 'งานใหม่ที่เหมาะกับคุณ',
          message: 'มีงาน "$jobTitle" ที่เหมาะกับคุณ',
          type: NotificationType.newJob,
          createdAt: DateTime.now(),
          isRead: false,
          jobId: jobId,
        );

        _notifications.insert(0, notification);
        notifyListeners();
        return;
      }

      await fetchNotifications(staffId);
    } catch (e) {
      debugPrint('Error refreshing after new job notification: $e');
    }
  }

  /// Create check-in reminder — server-driven; refresh locally when online
  Future<void> createCheckInReminderNotification({
    required String staffId,
    required String jobId,
    required String jobTitle,
    required DateTime jobStartTime,
  }) async {
    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Creating check-in reminder notification');

        final timeFormat =
            '${jobStartTime.hour.toString().padLeft(2, '0')}:${jobStartTime.minute.toString().padLeft(2, '0')}';

        final notification = NotificationModel(
          id: 'notif-checkin-${DateTime.now().millisecondsSinceEpoch}',
          title: 'แจ้งเตือนเช็คอิน',
          message:
              'อย่าลืมเช็คอินก่อนเข้างาน "$jobTitle" พรุ่งนี้ $timeFormat',
          type: NotificationType.checkInReminder,
          createdAt: DateTime.now(),
          isRead: false,
          jobId: jobId,
        );

        _notifications.insert(0, notification);
        notifyListeners();
        return;
      }

      await fetchNotifications(staffId);
    } catch (e) {
      debugPrint('Error refreshing check-in reminder: $e');
    }
  }

  /// Start check-in session — GET /api/staff/jobs/{id}/check-in-requirements
  Future<CheckInSession?> startCheckInSession(String jobId) async {
    _setLoading(true);
    _error = null;

    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Starting check-in session');
        await Future.delayed(const Duration(milliseconds: 500));

        _currentCheckInSession = CheckInSession(
          jobId: jobId,
          requirements: _generateMockCheckInRequirements(jobId),
        );
        notifyListeners();
        return _currentCheckInSession;
      }

      final response = await _apiClient.get(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/check-in-requirements',
      );

      if (response.statusCode == 200) {
        final List<dynamic> requirementsJson = response.data is List
            ? response.data as List
            : (response.data['requirements'] ?? []);
        final requirements = requirementsJson
            .whereType<Map>()
            .map((json) => CheckInRequirementModel.fromJson(
                  Map<String, dynamic>.from(json),
                ))
            .toList();

        _currentCheckInSession = CheckInSession(
          jobId: jobId,
          requirements: requirements,
        );
        notifyListeners();
        return _currentCheckInSession;
      }

      return null;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error starting check-in session: ${e.message}');
      return null;
    } catch (e) {
      _error = 'Failed to start check-in';
      debugPrint('Error starting check-in session: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Mark step as completed
  void completeStep(String requirementId) {
    if (_currentCheckInSession != null) {
      _currentCheckInSession = _currentCheckInSession!.copyWith(
        completedSteps: {
          ..._currentCheckInSession!.completedSteps,
          requirementId,
        },
      );
      notifyListeners();
    }
  }

  /// Complete check-in — POST with GPS for geofence
  Future<bool> completeCheckIn(
    String jobId, {
    required double latitude,
    required double longitude,
    double? accuracyMeters,
  }) async {
    if (_currentCheckInSession == null ||
        !_currentCheckInSession!.isCompleted) {
      _error = 'กรุณาอ่านข้อมูลทั้งหมดก่อนเช็คอิน';
      notifyListeners();
      return false;
    }

    _setLoading(true);
    _error = null;

    try {
      // ========== BYPASS API MODE (Development) ==========
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Completing check-in');
        await Future.delayed(const Duration(milliseconds: 500));

        _currentCheckInSession = _currentCheckInSession!.copyWith(
          completedAt: DateTime.now(),
        );
        notifyListeners();
        _setLoading(false);
        
        // Clear session after successful check-in
        Future.delayed(const Duration(seconds: 1), () {
          _currentCheckInSession = null;
          notifyListeners();
        });
        
        return true;
      }
      // ===================================================

      final response = await _apiClient.post(
        '${AppConstants.staffApiPrefix}/jobs/$jobId/check-in',
        data: {
          'completedSteps': _currentCheckInSession!.completedStepNumbers,
          'latitude': latitude,
          'longitude': longitude,
          if (accuracyMeters != null) 'accuracyMeters': accuracyMeters,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _currentCheckInSession = _currentCheckInSession!.copyWith(
          completedAt: DateTime.now(),
        );
        notifyListeners();
        _setLoading(false);
        
        // Clear session after successful check-in
        Future.delayed(const Duration(seconds: 1), () {
          _currentCheckInSession = null;
          notifyListeners();
        });
        
        return true;
      }

      _setLoading(false);
      return false;
    } on ApiException catch (e) {
      _error = e.message;
      debugPrint('Error completing check-in: ${e.message}');
      _setLoading(false);
      return false;
    } catch (e) {
      _error = 'Failed to complete check-in';
      debugPrint('Error completing check-in: $e');
      _setLoading(false);
      return false;
    }
  }

  /// Cancel check-in session
  void cancelCheckInSession() {
    _currentCheckInSession = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Fetch active announcements — GET /api/staff/announcements/active
  Future<List<AnnouncementModel>> fetchActiveAnnouncements({
    String locale = 'th',
  }) async {
    try {
      if (AppConstants.isDevelopmentMode && AppConstants.bypassLogin) {
        debugPrint('🚀 BYPASS API: Loading mock announcements');
        await Future.delayed(const Duration(milliseconds: 300));
        return _generateMockAnnouncements();
      }

      final response = await _apiClient.get(
        '${AppConstants.staffApiPrefix}/announcements/active',
        queryParameters: {'locale': locale},
      );

      if (response.statusCode == 200) {
        final List<dynamic> announcementsJson = response.data is List
            ? response.data as List
            : (response.data['announcements'] ?? []);
        return announcementsJson
            .whereType<Map>()
            .map((json) =>
                AnnouncementModel.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      return [];
    } on ApiException catch (e) {
      debugPrint('Error fetching announcements: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      return [];
    }
  }

  // ========== MOCK DATA GENERATORS (Development) ==========

  List<NotificationModel> _generateMockNotifications() {
    final now = DateTime.now();
    return [
      NotificationModel(
        id: 'notif-checkin-today',
        title: 'แจ้งเตือนเช็คอิน - วันนี้!',
        message: 'อย่าลืมเช็คอินก่อนเข้างาน "พยาบาลตรวจสุขภาพ - บริษัทเอกชน" วันนี้ 09:00',
        type: NotificationType.checkInReminder,
        createdAt: now.subtract(const Duration(minutes: 10)),
        isRead: false,
        jobId: 'job-hired-today',
      ),
      NotificationModel(
        id: 'notif-001',
        title: 'งานใหม่ที่เหมาะกับคุณ',
        message: 'มีงาน "พยาบาลประจำคลินิก - กะเช้า" ที่เหมาะกับคุณ',
        type: NotificationType.newJob,
        createdAt: now.subtract(const Duration(minutes: 30)),
        isRead: false,
        jobId: 'job-new-001',
      ),
      NotificationModel(
        id: 'notif-002',
        title: 'แจ้งเตือนเช็คอิน',
        message: 'อย่าลืมเช็คอินก่อนเข้างาน "พยาบาลฉีดยา" พรุ่งนี้ 08:00',
        type: NotificationType.checkInReminder,
        createdAt: now.subtract(const Duration(hours: 2)),
        isRead: false,
        jobId: 'job-tomorrow-001',
      ),
      NotificationModel(
        id: 'notif-003',
        title: 'เตือนความจำงาน',
        message: 'งาน "ดูแลผู้สูงอายุที่บ้าน" จะเริ่มในอีก 1 ชั่วโมง',
        type: NotificationType.jobReminder,
        createdAt: now.subtract(const Duration(hours: 5)),
        isRead: true,
        jobId: 'job-today-001',
      ),
      NotificationModel(
        id: 'notif-004',
        title: 'คุณได้รับงานแล้ว!',
        message: 'ยินดีด้วย! คุณถูกเลือกจากรายการสำรองสำหรับงาน "พยาบาลตรวจสุขภาพ"',
        type: NotificationType.waitlistPromoted,
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
        jobId: 'job-promoted-001',
      ),
      NotificationModel(
        id: 'notif-005',
        title: 'ได้รับค่าตอบแทน',
        message: 'คุณได้รับค่าตอบแทน 3,500 บาท จากงาน "พยาบาลประจำคลินิก"',
        type: NotificationType.paymentReceived,
        createdAt: now.subtract(const Duration(days: 2)),
        isRead: true,
        jobId: 'job-completed-001',
      ),
    ];
  }

  List<AnnouncementModel> _generateMockAnnouncements() {
    final now = DateTime.now();
    return [
      AnnouncementModel(
        id: 'announce-001',
        title: 'ยินดีต้อนรับสู่ MedShift Thailand! 🎉',
        message: '''
ขอบคุณที่เข้าร่วมเป็นส่วนหนึ่งของเรา!

MedShift Thailand เป็นแพลตฟอร์มที่เชื่อมโยงพยาบาลกับโอกาสในการทำงานที่หลากหลาย เรามุ่งมั่นที่จะสร้างสภาพแวดล้อมการทำงานที่ยืดหยุ่น โปร่งใส และเป็นธรรมสำหรับทุกคน

**คุณสมบัติหลักของแพลตฟอร์ม:**
• เลือกงานที่เหมาะกับคุณได้อย่างอิสระ
• ระบบการชำระเงินที่รวดเร็วและโปร่งใส
• การสนับสนุนจากทีมงานตลอด 24 ชั่วโมง
• ข้อมูลงานที่ครบถ้วนและชัดเจน

หากมีคำถามหรือต้องการความช่วยเหลือ ติดต่อเราได้ที่:
📧 support@medshift.co.th
📱 02-xxx-xxxx

ขอให้มีความสุขกับการทำงาน! 💙
''',
        type: 'success',
        createdAt: now.subtract(const Duration(days: 7)),
        isActive: true,
      ),
      AnnouncementModel(
        id: 'announce-002',
        title: 'การอัปเดตระบบ - 25 พฤษภาคม 2026',
        message: '''
📢 **ประกาศปรับปรุงระบบ**

เราจะทำการอัปเดตระบบในวันที่ 25 พฤษภาคม 2026 เวลา 02:00 - 04:00 น.

**การเปลี่ยนแปลง:**
✅ ปรับปรุงความเร็วของระบบ
✅ เพิ่มฟีเจอร์การค้นหางานที่ดีขึ้น
✅ แก้ไขข้อบกพร่องเล็กน้อย

**หมายเหตุ:** ในช่วงเวลาดังกล่าว ท่านอาจไม่สามารถเข้าใช้งานได้ชั่วคราว

ขออภัยในความไม่สะดวก และขอบคุณสำหรับความเข้าใจ 🙏
''',
        type: 'info',
        createdAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.add(const Duration(days: 5)),
        isActive: true,
      ),
    ];
  }

  List<CheckInRequirementModel> _generateMockCheckInRequirements(String jobId) {
    return [
      CheckInRequirementModel(
        id: 'req-001',
        stepNumber: 1,
        title: 'ข้อกำหนดและเงื่อนไข',
        content: '''
**ข้อกำหนดทั่วไป:**

1. พนักงานต้องมาถึงสถานที่ทำงานตรงเวลา หากมาสายเกิน 15 นาที จะถือว่าขาดงาน
2. ต้องแต่งกายสุภาพตามระเบียบของคลินิก
3. ต้องปฏิบัติตามคำสั่งของหัวหน้าคลินิกอย่างเคร่งครัด
4. ห้ามใช้โทรศัพท์มือถือในเวลาทำงาน ยกเว้นกรณีฉุกเฉิน
5. ต้องรักษาความลับของผู้ป่วยและข้อมูลของคลินิก

**ข้อปฏิบัติด้านความปลอดภัย:**

1. ต้องสวมอุปกรณ์ป้องกันส่วนบุคคล (PPE) ตลอดเวลา
2. ปฏิบัติตามขั้นตอนการทำความสะอาดและฆ่าเชื้ออย่างเคร่งครัด
3. แจ้งหัวหน้างานทันทีหากพบสิ่งผิดปกติ
4. ห้ามนำอาหารหรือเครื่องดื่มเข้าในพื้นที่ปฏิบัติงาน

**การยกเลิกงาน:**

- หากยกเลิกงานก่อนเวลา 24 ชั่วโมง จะมีค่าปรับ 50 บาท
- หากยกเลิกงานน้อยกว่า 24 ชั่วโมง จะมีค่าปรับ 100 บาท
- หากขาดงานโดยไม่แจ้ง จะมีค่าปรับ 200 บาท และอาจถูกระงับบัญชี
        ''',
        type: RequirementType.terms,
        estimatedReadTimeSeconds: 60,
      ),
      CheckInRequirementModel(
        id: 'req-002',
        stepNumber: 2,
        title: 'กระบวนการและขั้นตอนของคลินิก',
        content: '''
**ขั้นตอนการเริ่มงาน:**

1. รายงานตัวที่แผนกต้อนรับ พร้อมบัตรประชาชน
2. รับเครื่องแบบและอุปกรณ์จากแผนกพยาบาล
3. เข้าร่วมการบรีฟกับหัวหน้าทีม (15 นาที)
4. รับมอบหมายงานและพื้นที่รับผิดชอบ

**หน้าที่และความรับผิดชอบ:**

• ตรวจสอบอุปกรณ์ทางการแพทย์ก่อนใช้งาน
• บันทึกข้อมูลผู้ป่วยในระบบอย่างถูกต้องและครบถ้วน
• ประสานงานกับแพทย์และพยาบาลคนอื่นในทีม
• รายงานสถานการณ์ที่สำคัญให้หัวหน้าทีมทราบทันที

**ขั้นตอนการสิ้นสุดงาน:**

1. ส่งมอบงานให้กะถัดไป (ถ้ามี)
2. บันทึกสรุปการทำงานของวัน
3. คืนอุปกรณ์และตรวจสอบความเรียบร้อย
4. ออกจากคลินิกผ่านแผนกต้อนรับเท่านั้น
        ''',
        type: RequirementType.clinicRules,
        estimatedReadTimeSeconds: 45,
      ),
      CheckInRequirementModel(
        id: 'req-003',
        stepNumber: 3,
        title: 'ข้อมูลการติดต่อและที่จอดรถ',
        content: '''
**ข้อมูลการติดต่อ:**

📞 เบอร์คลินิก: 02-123-4567
📞 หัวหน้าพยาบาล: 089-123-4567 (คุณสมหญิง)
📞 ฉุกเฉิน: 1669

**ที่อยู่:**
123 ถนนสุขุมวิท แขวงคลองเตย เขตคลองเตย กรุงเทพฯ 10110

**ที่จอดรถ:**

🚗 รถยนต์: จอดที่ลานจอดด้านหลังคลินิก (ฟรี)
🏍️ รถจักรยานยนต์: จอดที่ด้านข้างอาคาร (ฟรี)

⚠️ กรุณาติดสติ๊กเกอร์จอดรถที่ได้รับจากแผนกต้อนรับ

**วิธีการเดินทาง:**

🚇 BTS: ลงสถานีอโศก ออกทางออก 3 เดินประมาณ 5 นาที
🚇 MRT: ลงสถานีสุขุมวิท ออกทางออก 2 เดินประมาณ 7 นาที
🚌 รถเมล์: สาย 2, 25, 38, 71 ลงป้ายตรงข้ามคลินิก

**สิ่งอำนวยความสะดวก:**

• ห้องพักพนักงาน: ชั้น 3
• ห้องอาหาร: ชั้น 2 (มีอาหารกลางวันฟรี)
• ห้องน้ำพนักงาน: ทุกชั้น
• ตู้ล็อคเกอร์: ชั้น 3 (นำกุญแจมาเอง)
        ''',
        type: RequirementType.contactInfo,
        estimatedReadTimeSeconds: 40,
      ),
      CheckInRequirementModel(
        id: 'req-004',
        stepNumber: 4,
        title: 'ขั้นตอนฉุกเฉินและความปลอดภัย',
        content: '''
**แผนฉุกเฉินกรณีเพลิงไหม้:**

1. 🔥 กดปุ่มแจ้งเหตุเพลิงไหม้ที่ใกล้ที่สุด
2. 📞 โทรแจ้ง 1669 และแจ้งแผนกต้อนรับ
3. 🚪 นำผู้ป่วยและผู้มาเยี่ยมออกจากอาคารผ่านบันไดหนีไฟ
4. 🚫 ห้ามใช้ลิฟต์โดยเด็ดขาด
5. 📍 รวมตัวที่จุดนัดพบหน้าอาคาร

**แผนฉุกเฉินกรณีแผ่นดินไหว:**

1. 🛑 หยุดทำงานและหาที่กำบัง (ใต้โต๊ะ, กรอบประตู)
2. ⛑️ ปกป้องศีรษะและลำตัว
3. 🚫 อย่าวิ่งออกจากอาคารทันที
4. ⏱️ รอให้แผ่นดินไหวหยุดก่อน จึงค่อยอพยพ

**อุปกรณ์ความปลอดภัย:**

✓ ถังดับเพลิง: ติดตั้งทุก 20 เมตร
✓ ชุด Fire Hose: ทุกชั้น
✓ Exit Sign: ทุกทางออก
✓ ปุ่มแจ้งเพลิงไหม้: สีแดง ติดผนัง

**เบอร์ฉุกเฉิน:**

🚨 เพลิงไหม้: 199
🚑 ฉุกเฉินการแพทย์: 1669
👮 ตำรวจ: 191
⚡ ไฟฟ้าขัดข้อง: 1130

**การป้องกันการติดเชื้อ:**

1. ล้างมือด้วยแอลกอฮอล์เจลบ่อยๆ
2. สวมหน้ากากอนามัยตลอดเวลา
3. เปลี่ยนถุงมือทุกครั้งหลังสัมผัสผู้ป่วย
4. ทิ้งขะในถังขยะติดเชื้อ (สีแดง) เท่านั้น
5. หากมีอาการป่วย ต้องแจ้งหัวหน้าทีมทันที
        ''',
        type: RequirementType.emergencyProcedure,
        estimatedReadTimeSeconds: 50,
      ),
    ];
  }
}
