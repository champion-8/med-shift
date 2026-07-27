# Azure free-tier demo (recommended path)

สำหรับ **web demo ศูนย์บาท** ใช้ชุดนี้:

| ส่วน | ของ | ทำไม |
|------|-----|------|
| **Web (Clinic/Admin)** | **Vercel Free** | Next.js ง่ายสุด, HTTPS ฟรี, ไม่กินโควต้า Azure CPU |
| **API** | **Azure App Service F1 (Free)** | รัน .NET, HTTPS ฟรี |
| **DB** | **Azure SQL free offer** | ตรงกับ local (SQL Server), มี EF migrations |
| **Mobile** | ชี้ `baseUrl` ไป API บน Azure | ยังไม่ทำ iOS |

**อย่าใช้ App Service สำหรับ web ตอน demo** — F1 มีแค่ ~60 นาที CPU/วัน ถ้ารันทั้ง web+API จะเต็มเร็ว; แยก web ไป Vercel ดีกว่า

---

## Free tier ที่เกี่ยวข้อง (ประมาณการ)

| บริการ | โควต้าฟรี (demo) |
|--------|------------------|
| App Service **F1** | ~**60 CPU นาที/วัน**, RAM ~1 GB, storage ~1 GB — เหมาะทดลองเท่านั้น |
| Azure SQL **free offer** | สูงสุด **10 DB/subscription**, ~**100,000 vCore-seconds/เดือน**, storage ~**32 GB**/DB — เกินแล้ว DB หยุดจนรอบถัดไปหรืออัปเกรด |
| Vercel Hobby | deploy จาก Git, HTTPS, โควต้า build/bandwidth ตามแผนฟรี |
| Custom domain | ไม่จำเป็นสำหรับ demo — ใช้ `*.azurewebsites.net` + `*.vercel.app` |

ตั้ง **Budget alert = $1** ทันทีหลังสมัคร Azure กันเผลอเปิด SKU เสียเงิน

---

## Step 0 — บัญชี

1. สมัคร [Azure](https://azure.microsoft.com/free/) (ใช้ Pay-as-you-go หลัง trial ก็ได้ แต่เปิด budget alert)
2. สมัคร [Vercel](https://vercel.com) ด้วย GitHub/GitLab
3. เตรียม repo MedShift บน GitHub (หรือ Git อื่นที่ Vercel/Azure ดึงได้)

---

## Step 1 — Resource Group

1. Azure Portal → **Resource groups** → **Create**
2. ชื่อ เช่น `rg-medshift-demo`
3. Region ใกล้ผู้ใช้ demo (เช่น `Southeast Asia`)
4. Create

---

## Step 2 — Azure SQL (free offer)

1. **Create a resource** → **SQL Database**
2. Subscription + Resource group = `rg-medshift-demo`
3. Database name: `MedShift`
4. Server → **Create new**:
   - Server name: `medshift-demo-<unique>`
   - Admin login / password: เก็บไว้เอง (แข็งแรง)
   - เลือก location เดียวกับ RG
5. หาตัวเลือก **Apply free database offer** / Free offer → **เปิดใช้** (สำคัญ)
6. Compute+storage: ให้เป็นแบบที่ผูก free offer (มักเป็น Serverless GP)
7. Networking:
   - เปิด **Allow Azure services and resources to access this server**
   - เพิ่ม firewall rule เป็น IP ของคุณ (ตอนทดสอบจากเครื่อง) ถ้าต้องการต่อจาก SSMS
8. Create → รอเสร็จ

### Connection string

Portal → SQL database → **Connection strings** → ADO.NET  

แก้เป็นประมาณ:

```text
Server=tcp:medshift-demo-xxxx.database.windows.net,1433;Initial Catalog=MedShift;Persist Security Info=False;User ID=YOUR_ADMIN;Password=YOUR_PASSWORD;MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;
```

คัดลอกไปใช้ใน Step 4

---

## Step 3 — App Service (API) แผน F1

1. **Create a resource** → **Web App**
2. ชื่อ: `medshift-api-demo-<unique>` → จะได้  
   `https://medshift-api-demo-xxxx.azurewebsites.net`
3. Publish: **Code**
4. Runtime: **.NET 9 (LTS)** (หรือเวอร์ชันใกล้เคียงที่ portal มี)
5. OS: **Windows** หรือ **Linux** — แนะนำ **Linux** ถ้ามี .NET 9
6. Region: เดียวกับ SQL
7. App Service Plan → **Create new** → Pricing: **Free F1**
8. Create

### Deploy API

เลือกอย่างใดอย่างหนึ่ง:

**A) GitHub Actions / Deployment Center (แนะนำ)**  
1. Web App → **Deployment Center** → เชื่อม GitHub → repo / branch `main`  
2. ใช้ workflow ใน repo: [`.github/workflows/main_medshift-api-demo.yml`](../.github/workflows/main_medshift-api-demo.yml)  
   (ไฟล์ที่ Deployment Center สร้าง — แก้ให้ชี้ `api/src/MedShift.Api/MedShift.Api.csproj` แล้ว)  
3. จุดสำคัญ:
   - `dotnet-version: '9.0.x'`
   - `dotnet restore` / `publish` ต้องมี path โปรเจกต์ — **ห้าม** `dotnet build --configuration Release` เปล่าที่ root
4. Push ขึ้น `main` แล้วดูแท็บ **Actions**

ตัวอย่างขั้นที่ถูก:

```yaml
env:
  PROJECT: api/src/MedShift.Api/MedShift.Api.csproj
  DOTNET_VERSION: '9.0.x'

- run: dotnet restore ${{ env.PROJECT }}
- run: dotnet publish ${{ env.PROJECT }} -c Release -o ${{ env.DOTNET_ROOT }}/myapp --no-restore
```

**B) จากเครื่อง (ครั้งแรกทดลอง)**  

```powershell
cd d:\Git\medshift\api
dotnet publish src/MedShift.Api/MedShift.Api.csproj -c Release -o .\publish
# ติดตั้ง Azure CLI + ส่วนขยาย แล้ว:
az webapp deploy --resource-group rg-medshift-demo --name medshift-api-demo-xxxx --src-path .\publish --type zip
```

(คำสั่ง `az` อาจต่างเล็กน้อยตามเวอร์ชัน — ถ้า error ใช้ **Deployment Center** แทน)

---

## Step 4 — Application settings (API)

Web App → **Settings** → **Environment variables** / **Configuration** → Application settings  
เพิ่ม (ชื่อใช้ `__` แทน `:` ):

| Name | Value |
|------|--------|
| `Database__Provider` | `SqlServer` |
| `ConnectionStrings__DefaultConnection` | *(connection string จาก Step 2)* |
| `Jwt__Issuer` | `MedShift` |
| `Jwt__Audience` | `MedShiftClients` |
| `Jwt__Key` | สตริงสุ่ม **≥ 32 ตัวอักษร** |
| `Jwt__ExpiryMinutes` | `1440` |
| `Firebase__Enabled` | `false` |
| `EmailSettings__Enabled` | `false` |
| `PaymentGateway__Provider` | `Simulated` |
| `ASPNETCORE_ENVIRONMENT` | `Production` |

**Save** → รอ restart

### ตรวจ API

เปิดเบราว์เซอร์:

`https://medshift-api-demo-xxxx.azurewebsites.net/openapi/v1.json`  

หรือลอง login ผ่าน web หลัง Step 5

Admin seed (ครั้งแรกที่ API ต่อ DB สำเร็จ):  
`admin@medshift.local` / `Admin@12345`

---

## Step 5 — Web บน Vercel (demo)

1. [vercel.com](https://vercel.com) → **Add New Project** → Import repo MedShift  
2. **Root Directory** = `web`  
3. Framework: Next.js (auto)  
4. Environment Variables:

| Name | Value |
|------|--------|
| `NEXT_PUBLIC_API_URL` | `https://medshift-api-demo-xxxx.azurewebsites.net` |

5. Deploy  
6. ได้ URL เช่น `https://medshift-xxx.vercel.app`

### CORS

API ตอนนี้ตั้ง `SetIsOriginAllowed(_ => true)` อยู่แล้วใน `Program.cs` — demo ใช้ได้  
(production จริงควรจำกัดเหลือโดเมน Vercel)

### ถ้า build พังเรื่อง `standalone`

`web/next.config.ts` มี `output: "standalone"` สำหรับ Docker — บน Vercel โดยปกติยัง build ได้  
ถ้ามีปัญหา ให้เอา `output: "standalone"` ออกเฉพาะตอน deploy Vercel (หรือใช้ env แยก) — บอก Agent ให้ช่วยได้

---

## Step 6 — ทดสอบ demo

1. เปิด Vercel URL → login clinic/admin  
2. Admin: `admin@medshift.local` / `Admin@12345`  
3. สมัคร/อนุมัติตาม flow เดิม  

### Flutter (ถ้าจะโชว์ staff app)

ใน `mobile/lib/core/constants/app_constants.dart` ชั่วคราว:

```dart
static const String baseUrl = 'https://medshift-api-demo-xxxx.azurewebsites.net';
```

แล้ว `flutter run` / build APK  
(อย่า commit URL demo ถ้าไม่ตั้งใจ)

---

## Step 7 — สิ่งที่ยังไม่ทำใน free demo (โอเคชั่วคราว)

| เรื่อง | สถานะ demo |
|--------|------------|
| อัปโหลด KYC บน disk App Service | ใช้ได้ชั่วคราว; **redeploy อาจหาย** — production ค่อยใส่ Blob |
| Custom domain / อีเมลจริง / FCM | ปิดไว้ก่อน (`Enabled=false`) |
| SLA / uptime | F1 ไม่มี SLA — cold / ช้าได้ |

---

## Checklist สั้นๆ

- [ ] Budget alert $1  
- [ ] Azure SQL + **free offer** เปิดแล้ว  
- [ ] App Service **F1** + settings (`ConnectionStrings`, `Jwt__Key`, `Database__Provider=SqlServer`)  
- [ ] API เปิด OpenAPI / login ได้  
- [ ] Vercel `web` + `NEXT_PUBLIC_API_URL` ชี้ API  
- [ ] ลอง login บน Vercel URL  

---

## Vercel vs App Service (web) — สรุปอีกครั้ง

| | Vercel | App Service (web) |
|--|--------|-------------------|
| Next.js demo | **ดีที่สุด** | ได้ แต่เปลือง F1 CPU |
| ฟรี tier | Hobby ใช้งาน demo สะดวก | F1 แชร์โควต้ากับ API |
| ตั้งค่า | Root = `web` + 1 env | ต้อง plan/runtime เพิ่ม |
| **เลือกสำหรับ demo นี้** | **ใช้ Vercel** | ไม่แนะนำตอนนี้ |

เอกสาร Oracle VM เดิมยังอยู่ที่ [README.md](./README.md) / [FREE_TIER.md](./FREE_TIER.md) — คนละทางกับชุด Azure demo นี้
