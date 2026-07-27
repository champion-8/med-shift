# MedShift API (.NET 9)

Backend สำหรับ MedShift Thailand — รองรับ 3 role: **Staff**, **Clinic**, **Admin**

## โครงสร้าง

```
api/
├── MedShift.slnx
└── src/
    ├── MedShift.Api            # Controllers / host
    ├── MedShift.Application    # DTOs + interfaces
    ├── MedShift.Domain         # Entities + enums
    └── MedShift.Infrastructure # EF Core, JWT, services
```

## Prerequisites

- .NET 9 SDK
- SQL Server Express ที่ `localhost\SQLEXPRESS` (user `sa` / `abcDEF00`)

## เริ่มต้นใช้งาน

### 1) สร้าง migration (ถ้ายังไม่มี)

```bash
cd api
dotnet ef migrations add InitialCreate -p src/MedShift.Infrastructure -s src/MedShift.Api -o Persistence/Migrations
```

### 2) รัน API

```bash
dotnet run --project src/MedShift.Api
```

ตอนสตาร์ท API จะ `Migrate` + seed ให้อัตโนมัติ (สร้าง DB `MedShift` ถ้ายังไม่มี)

- Default admin: `admin@medshift.local` / `Admin@12345`
- Connection: `localhost\SQLEXPRESS` user `sa` (ดู `appsettings.json`)

## API หลัก

| Prefix | Role |
|--------|------|
| `/api/auth/*` | สาธารณะ + me |
| `/api/staff/*` | Staff (mobile) |
| `/api/clinic/*` | Clinic (web) |
| `/api/admin/*` | Admin (web) |

### Auth
- `POST /api/auth/login`
- `POST /api/auth/register/staff`
- `POST /api/auth/register/clinic` → สถานะองค์กร `Pending` จนกว่า Admin อนุมัติ
- `GET /api/auth/me`

### Clinic ต้องถูก Approve ก่อนถึงจะสร้างงานได้
### Staff (พยาบาล/แพทย์) ต้องถูก Approve ก่อนถึงจะสมัคร/รับงานได้

### การจ่ายเงินตอนประกาศงาน (Payment Gateway)

คลินิกจ่าย **ค่าจ้างพนักงาน + ค่าธรรมเนียมแพลตฟอร์ม** ตอนประกาศงาน (`confirmGatewayPayment: true`)

**Simulated (ค่าเริ่มต้น)** — จ่ายทันทีในระบบ, งานเป็น `Open` + escrow `Held`

**GB Prime Pay (PromptPay QR)** — ตั้งใน `appsettings.json`:

```json
"PaymentGateway": {
  "Provider": "GbPrimePay",
  "GbPrimePay": {
    "BaseUrl": "https://api.globalprimepay.com",
    "Token": "YOUR_CUSTOMER_TOKEN",
    "SecretKey": "YOUR_SECRET_KEY",
    "PublicKey": "YOUR_PUBLIC_KEY",
    "WebhookPublicBaseUrl": "https://your-public-api.example"
  }
}
```

- สร้างงานเป็น `PendingPayment` + QR → คลินิกสแกน PromptPay
- Webhook: `POST /api/payments/gbprimepay/webhook` (ต้องเป็น public URL; ใช้ ngrok ตอน local)
- Poll: `GET /api/clinic/jobs/{id}/payment-status`
- เมื่อจ่ายสำเร็จ → `Open` + escrow `Held`; fee เข้า platform ledger
- ปิดงาน / no-show ยกเลิก: คืน escrow (fee ไม่คืน)
- Preview: `GET /api/clinic/billing/fee-config`, `GET /api/clinic/billing/payment-preview`

Admin endpoints:
- `GET /api/admin/staff/pending`
- `POST /api/admin/staff/{id}/approve`
- `POST /api/admin/staff/{id}/reject`
- `POST /api/admin/staff/{id}/suspend`

## Firebase / FCM push

In-app notifications always work. Live push uses **Firebase Admin SDK** (HTTP v1) with a service account JSON — not the legacy Server Key.

1. Place the Firebase service account file in `src/MedShift.Api/` (e.g. `medshiftnoti-firebase-adminsdk-….json`)
2. In `appsettings.json`:

```json
"Firebase": {
  "Enabled": true,
  "CredentialsPath": "medshiftnoti-firebase-adminsdk-fbsvc-a56220c9bd.json"
}
```

   Path can be absolute or relative to the API content root.

3. Mobile needs Firebase app config (`google-services.json` / `GoogleService-Info.plist`).  
   Android package / iOS bundle ID: **`com.medshift.thailand`**  
   In debug without Firebase, the app registers a placeholder device token so the API dry-run path is testable.

4. Clinic web: after login registers device via `PUT /api/clinic/notifications/device`.  
   For real browser FCM, add Firebase **Web** app + set `NEXT_PUBLIC_FIREBASE_*` and `NEXT_PUBLIC_FIREBASE_VAPID_KEY` in `web/.env.local`.  
   Without those, a debug placeholder token is used (in-app + FCM dry-run still work).

5. Test endpoint (staff JWT):

```http
PUT /api/staff/notifications/device
{ "firebaseDeviceToken": "any-token", "platform": "web" }

POST /api/staff/notifications/test-push
```

When `Enabled=false` or the credentials file is missing, the API logs `FCM dry-run` and still writes the in-app notification. Invalid FCM tokens are pruned automatically when live send reports Unregistered / InvalidArgument.

## Email (SMTP)

ตั้งใน `appsettings.json` → `EmailSettings` (Gmail: ใช้ App Password)

```json
"EmailSettings": {
  "Enabled": true,
  "SmtpServer": "smtp.gmail.com",
  "Port": 587,
  "UseSsl": true,
  "SenderName": "MedShift",
  "SenderEmail": "you@gmail.com",
  "Username": "you@gmail.com",
  "Password": "your-app-password"
}
```

- `Forgot password` ส่งรหัส 6 หลักไปอีเมลเมื่อ SMTP พร้อม
- ถ้า `Enabled=false` / ตั้งค่าไม่ครบ / ส่งไม่สำเร็จ → API คืน `resetCode` ใน response (โหมดทดสอบ)
- แนะนำย้าย `Password` ไป User Secrets / env ก่อนขึ้น production

## หมายเหตุ

- เปลี่ยน JWT Key ก่อนขึ้น production
- Web: `../web` (Next.js Clinic + Admin)
- Mobile: `../mobile` (Flutter)

## บัญชีทดสอบ

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@medshift.local` | `Admin@12345` |
| Clinic | `ui.clinic120741@test.local` | `Password1!` |
| Staff | `ui.nurse120741@test.local` | `Password1!` |

## E2E scripts

รันตอน API ขึ้นที่ `http://localhost:5080`:

```powershell
powershell -File scripts/e2e-hire-checkin-pay.ps1
powershell -File scripts/e2e-withdraw-approve.ps1
powershell -File scripts/e2e-withdraw-reject-announce.ps1
```
