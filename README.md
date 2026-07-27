# MedShift Thailand

Medical staffing marketplace

## โครงสร้างโปรเจกต์

```
d:\Git\medshift\
├── mobile\   # Flutter app (Nurse / Doctor — บุคคลรับงาน part-time)
├── web\      # Next.js (Clinic + Admin)
└── api\      # ASP.NET Core 9 + SQL Server Express
```

## Deploy (free tier)

### Azure demo (แนะนำถ้า Oracle สร้าง VM ไม่ได้)

Web demo → **Vercel** · API → **App Service F1** · DB → **Azure SQL free**  
คู่มือทีละขั้น: [`deploy/AZURE.md`](deploy/AZURE.md) · ตัวแปรตัวอย่าง: [`deploy/azure-appsettings.example.env`](deploy/azure-appsettings.example.env)

### Oracle Always Free VM (ทางเลือก)

ดูคู่มือ + โควต้า: [`deploy/FREE_TIER.md`](deploy/FREE_TIER.md) และ [`deploy/README.md`](deploy/README.md)

สรุปสั้นๆ (Oracle): **ARM ≤ 2 OCPU / 12 GB** + Docker Compose (`Postgres` + API + Next.js) — **ยังไม่รองรับ iOS**

```bash
cd deploy
cp .env.example .env   # แก้รหัสผ่าน + JWT + PUBLIC_API_URL
docker compose up -d --build
```

Local Windows ยังใช้ SQL Server Express ตามด้านบนได้ตามเดิม

## Quick start

### API

1. เปิด SQL Server Express: `localhost\SQLEXPRESS` (sa / abcDEF00)
2. รัน API:

```bash
cd api
dotnet run --project src/MedShift.Api --launch-profile http
```

API: [http://localhost:5080](http://localhost:5080)  
Admin เริ่มต้น: `admin@medshift.local` / `Admin@12345`

### Web

ต้องการ Node 24+

```bash
cd web
npm install
npm run dev
```

เปิด [http://localhost:3000](http://localhost:3000)

### Mobile

```bash
cd mobile
flutter pub get
flutter run -d chrome --web-port=7357
```

API URL ในแอป: `http://localhost:5080` (`lib/core/constants/app_constants.dart`)

## บัญชีทดสอบ

| Role | Email | Password |
|------|-------|----------|
| Admin | `admin@medshift.local` | `Admin@12345` |
| Clinic | `ui.clinic120741@test.local` | `Password1!` |
| Staff | `ui.nurse120741@test.local` | `Password1!` |

Clinic + Staff ต้องถูก Admin อนุมัติก่อนโพสต์/รับงาน

## E2E scripts (API ต้องรันอยู่)

```powershell
cd api
powershell -File scripts/e2e-hire-checkin-pay.ps1
powershell -File scripts/e2e-withdraw-approve.ps1
powershell -File scripts/e2e-withdraw-reject-announce.ps1
```

## Flow หลักที่พร้อมแล้ว

Staff สมัครงาน → Clinic จ้าง → Check-in → Start → Complete & pay → Wallet → ถอนเงิน → Admin อนุมัติ/ปฏิเสธ  
+ Admin อนุมัติ clinic/staff + ประกาศ + Report issues + FCM (ตั้ง `Firebase:CredentialsPath` ใน API)  
+ จ่ายตอนประกาศงาน (Simulated / GB PrimePay QR) + Staff↔Clinic rating + Clinic web device token