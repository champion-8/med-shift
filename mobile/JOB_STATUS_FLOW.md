# Job Status Flow

## สถานะงานตลอด Lifecycle

### 0️⃣ **PENDING PAYMENT** (รอชำระเงิน)
- คลินิกสร้างงานแล้ว แต่ยังไม่ได้ชำระผ่าน payment gateway
- กรณี **GB Prime Pay / PromptPay QR**: แสดง QR ให้คลินิกสแกน
- กรณี **Simulated**: ข้ามขั้นนี้ ไป `Open` ทันทีหลังสร้างงาน
- ยังไม่โชว์ใน Job Feed ของ staff
- **Actions**: รอ webhook / poll payment-status หรือยกเลิกงาน

```dart
JobStatus.pendingPayment
```

### 1️⃣ **OPEN** (เปิดรับสมัคร)
- จ่ายเงินสำเร็จแล้ว (escrow Held + platform fee)
- แสดงในหน้า Job Feed
- พยาบาลสามารถดูรายละเอียดและสมัครได้
- **Actions**: Apply for Job

```dart
JobStatus.open
```

### 2️⃣ **APPLIED** (มีการสมัคร)
- มีพยาบาลสมัครงานแล้ว
- คลินิกกำลังพิจารณาผู้สมัคร
- **Actions**: Review Applications, Select Staff

```dart
JobStatus.applied
```

### 3️⃣ **SELECTING** (กำลังพิจารณา)
- คลินิกกำลังพิจารณา / ใส่ waitlist
- **Actions**: Confirm Hire, Add to Waitlist

```dart
JobStatus.selecting
```

### 4️⃣ **CONFIRMED** (ยืนยันการจ้างแล้ว)
- คลินิกเลือกพยาบาลและยืนยันจ้างแล้ว
- พยาบาลได้รับการแจ้งเตือน
- **Actions**: Check-in (เมื่อถึงวันงาน), Cancel Job

```dart
JobStatus.confirmed
```

### 5️⃣ **CHECKED-IN** (เช็คอินแล้ว)
- พยาบาลเช็คอินเข้างานแล้ว
- **Actions**: Start Work, Report Issues

```dart
JobStatus.checkedIn
```

### 6️⃣ **IN-PROGRESS** (กำลังทำงาน)
- งานกำลังดำเนินการ
- **Actions**: Complete Work, Report Issues

```dart
JobStatus.inProgress
```

### 7️⃣ **COMPLETED** (เสร็จสิ้น)
- งานเสร็จ + จ่ายค่าจ้างจาก escrow เข้า wallet staff
- **Actions**:
  - Clinic: Rate staff (`POST /api/clinic/jobs/{id}/rate`)
  - Staff: Rate clinic (`POST /api/staff/jobs/{id}/rate-clinic`)

```dart
JobStatus.completed
```

### ❌ **CANCELLED** (ยกเลิก)
- ยกเลิกโดยคลินิกหรือ staff
- ถ้ายัง Pending payment → ไม่เรียก refund gateway
- ถ้า Held → คืน escrow (staff amount); platform fee ไม่คืน
- **Can occur from**: PENDING_PAYMENT, OPEN, APPLIED, SELECTING, CONFIRMED (+ no-show path)

```dart
JobStatus.cancelled
```

---

## การจ่ายเงินตอนประกาศงาน

```
Clinic create job (confirmGatewayPayment)
        │
        ├─ Simulated ──────────────────────► OPEN + JobPayment Held
        │
        └─ GbPrimePay QR
              │
              ▼
        PENDING_PAYMENT + JobPayment Pending
              │
     scan PromptPay QR
              │
              ▼
   webhook / payment-status poll
              │
              ▼
        OPEN + JobPayment Held
        (+ platform fee ledger)
```

- Preview: `GET /api/clinic/billing/payment-preview`
- Poll: `GET /api/clinic/jobs/{id}/payment-status`
- Webhook: `POST /api/payments/gbprimepay/webhook`

---

## Flow Diagram

```
┌────────────────┐
│ PENDING_PAYMENT│──(paid)──┐
└───────┬────────┘          │
        │(cancel)           ▼
        ▼              ┌─────────┐     ┌─────────┐     ┌───────────┐     ┌───────────┐
   [Cancelled]         │  OPEN   │────>│ APPLIED │────>│ SELECTING │────>│ CONFIRMED │
                       └─────────┘     └─────────┘     └───────────┘     └───────────┘
                            │               │                 │                  │
                          [Cancel]       [Cancel]          [Cancel]      [Cancel/Check-in]
                                                                               │
                                                                               ▼
                                                                        ┌─────────────┐
                                                                        │ CHECKED-IN  │
                                                                        └─────────────┘
                                                                               │
                                                                               ▼
                                                                        ┌─────────────┐
                                                                        │ IN-PROGRESS │
                                                                        └─────────────┘
                                                                               │
                                                                               ▼
                                                                        ┌─────────────┐
                                                                        │  COMPLETED  │
                                                                        │ rate both   │
                                                                        └─────────────┘
```

---

## Payment lifecycle (JobPayment)

| Status | ความหมาย |
|--------|----------|
| Pending | รอสแกน QR / ยืนยัน gateway |
| Held | จ่ายแล้ว ถือ escrow ค่าจ้าง staff |
| Released | จ่ายเข้า wallet staff หลัง Complete |
| Refunded | คืน escrow ให้คลินิก (ยกเลิก / no-show ไม่ promote) |

---

## Related API notes

- Staff open jobs ไม่รวม `PendingPayment`
- Clinic members ลงทะเบียน push: `PUT /api/clinic/notifications/device`
- Staff ลงทะเบียน push: `PUT /api/staff/notifications/device`
