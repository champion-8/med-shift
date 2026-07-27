# 🔧 Development Configuration

## Bypass Login (ไม่ต้องต่อ API)

สำหรับการพัฒนาแอป คุณสามารถเปิดใช้งาน **Bypass Login Mode** เพื่อข้ามการเชื่อมต่อ API และเข้าสู่ระบบด้วยข้อมูล Mock User

### 🚀 วิธีเปิดใช้งาน

1. ไปที่ไฟล์: `lib/core/constants/app_constants.dart`

2. ตั้งค่า flags ดังนี้:

```dart
// Development Mode - Bypass Login (ไม่ต้องต่อ API)
static const bool isDevelopmentMode = true;  // เปิด Development Mode
static const bool bypassLogin = true;        // เปิด Bypass Login
```

3. บันทึกไฟล์และรีสตาร์ทแอป

### ✅ ผลลัพธ์

เมื่อเปิดใช้งาน:
- **ไม่ต้องกรอกอีเมล/รหัสผ่านที่ถูกต้อง** - กรอกอะไรก็ได้ (ต้องผ่าน validation เท่านั้น)
- **ข้ามการเรียก API ทั้งหมด** - ไม่มีการเชื่อมต่อ backend เลย
- **ใช้ Mock User Data** - เข้าสู่ระบบด้วยข้อมูลทดสอบทันที
- **แสดง Mock Jobs** - งาน 5 งานพร้อม hired jobs และ waitlist jobs
- **แสดง Mock Wallet** - ยอดเงิน 2,450.50 บาท พร้อม transaction history
- **เห็น Debug Log** - มีข้อความ 🚀 BYPASS ใน console

### 👤 Mock User Data

ข้อมูลผู้ใช้ทดสอบที่ใช้ใน Development Mode:

```dart
- ชื่อ: สมหญิง ใจดี
- อีเมล: nurse@test.com
- เบอร์โทร: 081-234-5678
- License: RN-12345
- ความเชี่ยวชาญ: พยาบาลวิชาชีพ
- ประสบการณ์: 5 ปี
- Rating: 4.8 ⭐
- งานที่ทำแล้ว: 120 งาน
```

### 💼 Mock Jobs Data

เมื่อเปิด Development Mode จะมี **Mock Jobs** ให้ทดสอบ:

**งานที่เปิดรับสมัคร (5 งาน):**
1. พยาบาลดูแลผู้สูงอายุ - กะเช้า (350 บาท/ชม.)
2. พยาบาลฉีดยา - คลินิกเอกชน (400 บาท/ชม.)
3. พยาบาลดูแลผู้ป่วยโควิด - กะดึก (500 บาท/ชม.)
4. พยาบาลดูแลเด็ก - รพ.เอกชน (450 บาท/ชม.)
5. พยาบาลตรวจสุขภาพ - งาน Event (300 บาท/ชม.)

**งานที่ได้รับการจ้าง (1 งาน):**
- พยาบาลประจำคลินิก - กะเช้า (380 บาท/ชม.)

**งาน Waitlist (1 งาน):**
- พยาบาล ICU - โรงพยาบาลใหญ่ (550 บาท/ชม.)

### 💰 Mock Wallet Data

**ยอดเงินคงเหลือ:** 2,450.50 บาท

**Transaction History (7 รายการ):**
1. ✅ รับเงิน 3,500 บาท - งานดูแลผู้สูงอายุ
2. ✅ รับเงิน 2,800 บาท - งานฉีดยา
3. ❌ ค่าปรับ -50 บาท - ยกเลิกงาน
4. ✅ รับเงิน 4,200 บาท - งานตรวจสุขภาพ
5. 🎁 โบนัส 500 บาท - ทำงานครบ 100 งาน
6. ✅ รับเงิน 3,600 บาท - งาน ICU
7. ⏳ รออนุมัติ 2,450 บาท - งานปัจจุบัน

### 🔄 การปิดใช้งาน (สำหรับ Production)

เมื่อพร้อม deploy จริง ให้เปลี่ยนเป็น:

```dart
static const bool isDevelopmentMode = false;
static const bool bypassLogin = false;
```

หรือสามารถใช้ environment variables:

```dart
static const bool isDevelopmentMode = 
    bool.fromEnvironment('DEV_MODE', defaultValue: false);
static const bool bypassLogin = 
    bool.fromEnvironment('BYPASS_LOGIN', defaultValue: false);
```

แล้ว run ด้วย:
```bash
flutter run --dart-define=DEV_MODE=true --dart-define=BYPASS_LOGIN=true
```

### ⚠️ คำเตือน

- **อย่าใช้ในโหมด Production** - ต้องปิด flag ก่อน build release
- **ไม่ปลอดภัย** - ใครๆ ก็เข้าได้ถ้า flag เปิดอยู่
- **ข้อมูลไม่ถูกบันทึก** - การเปลี่ยนแปลงจะหายหลัง restart

### 🧪 การทดสอบ

1. เปิด flag `bypassLogin = true`
2. ไปที่หน้า Login Screen
3. กรอกอีเมลและรหัสผ่านอะไรก็ได้ (ที่ผ่าน validation)
4. กด Login
5. ควรเข้าสู่ระบบได้ทันที โดยไม่มี API error

### 🐛 Debug Info

เมื่อ Bypass Login เปิดอยู่ คุณจะเห็น log ดังนี้:

```
🚀 BYPASS LOGIN MODE: ข้ามการเชื่อมต่อ API
✅ Mock Login สำเร็จ: สมหญิง ใจดี
```

---

## 📝 หมายเหตุเพิ่มเติม

### การแก้ไข Mock User Data

หากต้องการเปลี่ยนข้อมูล Mock User แก้ไขได้ที่:

**ไฟล์**: `lib/core/constants/app_constants.dart`

```dart
// Mock User Data (สำหรับ Development Mode)
static const String mockUserId = 'mock-user-001';
static const String mockUserEmail = 'nurse@test.com';
static const String mockUserFirstName = 'สมหญิง';
static const String mockUserLastName = 'ใจดี';
static const String mockUserPhone = '081-234-5678';
static const String mockLicenseNumber = 'RN-12345';
```

### การแก้ไข Mock Jobs

หากต้องการเปลี่ยนข้อมูล Mock Jobs แก้ไขได้ที่:

**ไฟล์**: `lib/providers/job_provider.dart`

```dart
// ฟังก์ชัน Mock Data Generators:
- _generateMockJobs()          // งานที่เปิดรับสมัคร
- _generateMockHiredJobs()     // งานที่ได้รับการจ้าง
- _generateMockWaitlistJobs()  // งานที่อยู่ใน Waitlist
```

### การแก้ไข Mock Wallet

หากต้องการเปลี่ยนข้อมูล Mock Wallet แก้ไขได้ที่:

**ไฟล์**: `lib/providers/wallet_provider.dart`

```dart
// ยอดเงินคงเหลือ (บรรทัด ~30)
_balance = 2450.50; // แก้ตรงนี้

// Transaction History
_generateMockTransactions()  // แก้ตรงนี้
```

### Custom Mock User ตาม Email

ระบบจะใช้อีเมลที่กรอกแทนค่า default ถ้ามีข้อความ:

```dart
email: email.isNotEmpty ? email : AppConstants.mockUserEmail,
```

ดังนั้นถ้ากรอก `test@example.com` ระบบจะใช้อีเมลนั้นใน Mock User

### 🎨 ทดสอบ UI ครบทุกหน้า

ด้วย Mock Data ที่ครบถ้วน คุณสามารถทดสอบ UI ทุกหน้าได้:

- ✅ **Login Screen** - ทดสอบ Login ด้วยข้อมูลใดก็ได้
- ✅ **Home Screen** - เห็นสถิติและข้อมูลสรุป
- ✅ **Job Feed Screen** - ดูงานทั้งหมด 5 งาน
- ✅ **Job Detail Screen** - คลิกดูรายละเอียดงาน
- ✅ **My Jobs Screen** - เห็นงานที่ได้รับการจ้าง + Waitlist
- ✅ **Wallet Screen** - เห็นยอดเงินและ transaction history
- ✅ **Profile Screen** - แก้ไขข้อมูลส่วนตัว
