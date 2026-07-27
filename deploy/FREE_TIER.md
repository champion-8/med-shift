# Free tier quotas (MedShift deploy stack)

Numbers change — verify on vendor docs before relying on them.  
**iOS / App Store is out of scope** (Apple Developer is paid).

Updated for guidance as of **July 2026**.

---

## 1. Oracle Cloud — Always Free (main host)

Docs: [Always Free Resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)

| Resource | Free allowance (Always Free tenancy) | Notes |
|----------|--------------------------------------|--------|
| **Ampere A1 (ARM)** | **2 OCPU + 12 GB RAM** total | ≈ 1,500 OCPU-hours + 9,000 GB-hours / month. Cut from former 4 OCPU / 24 GB (June 2026). Stay ≤ 2/12 or instances may stop. |
| **AMD Micro** | **2×** `VM.Standard.E2.1.Micro` (1/8 OCPU, 1 GB each) | Too small for this stack alone; optional extras. |
| **Block + boot storage** | **200 GB** total | Boot volumes count (min ~47 GB each). |
| **Outbound data** | Limited free egress (check current docs / region) | Prefer same-region traffic; don't stream huge media. |
| **Autonomous DB** | Optional Always Free ATP/ADW (small) | We use Postgres in Docker instead to save complexity. |
| **Trial credits** | Often **~$300 / 30 days** on signup | Separate from Always Free; don't put prod-only load on paid shapes without a budget alert. |

**Recommended VM for MedShift:** 1× Ampere **2 OCPU / 12 GB**, Ubuntu, Docker Compose from this folder.

**Why Postgres here:** Microsoft SQL Server containers are **amd64-only**; Ampere is **ARM**.

---

## 2. Postgres in Docker (on the VM)

| Item | Cost |
|------|------|
| Postgres 16 Alpine container | **$0** (runs on Oracle free VM) |
| Disk | Uses Oracle **200 GB** block/boot budget |

Suggested DB volume size for MVP: few GB is enough.

---

## 3. Cloudflare Pages (optional for static sites)

Docs: [Pages limits](https://developers.cloudflare.com/pages/platform/limits/)

| Free plan | Limit |
|-----------|--------|
| Builds / month | **500** (1 concurrent) |
| Files / site | **20,000** |
| Custom domains / project | **100** |
| Bandwidth / static requests | **Unlimited** (per Cloudflare marketing) |
| Workers (if used) | Often **100k requests/day** on Free |

**MedShift Clinic/Admin is Next.js SSR** — keep it on the Oracle VM (`web` service), not Pages, unless you later switch to static export.

---

## 4. Firebase Spark (push notifications)

Docs: [Firebase pricing](https://firebase.google.com/pricing/)

| Product (typical) | Spark (no-cost) ballpark |
|-------------------|---------------------------|
| Cloud Messaging (FCM) | **No-cost** for send (within product rules) |
| Spark overall | No card required; **exceeding a quota shuts that product off for the rest of the month** |
| Firestore (if you add it later) | ~**50k reads / 20k writes / day** |
| Hosting (if used) | Small storage + transfer caps on Spark |

For MedShift MVP, FCM-only on Spark is usually enough.

---

## 5. Email (Gmail SMTP)

| Item | Limit (typical) |
|------|------------------|
| Gmail SMTP (personal) | Roughly **~100–500 mails/day** depending on account; not for mass mail |
| Cost | **$0** with App Password |

Use for password-reset only. Don't commit App Passwords to git.

---

## 6. Neon Postgres (only if DB is off-VM)

Docs: [Neon plans](https://neon.com/docs/introduction/plans)

| Free | Limit |
|------|--------|
| Price | **$0 / month** |
| Storage / project | **0.5 GB** |
| Compute | **100 CU-hours / project / month**; scale-to-zero after idle |
| Egress | **~5 GB / month** |
| Projects | **100** |

**Not required** if Postgres runs on Oracle. Neon is a fallback if the VM is API-only.

---

## 7. Android distribution (no iOS)

| Path | Cost |
|------|------|
| Sideload APK / internal share | **$0** |
| Google Play Console | **One-time** registration fee (not Always Free) when you want store listing |
| Apple / iOS | **Skipped** (paid Developer Program) |

---

## 8. What this stack costs at MVP scale

| Piece | Expected |
|-------|----------|
| Oracle VM + Postgres + API + Web | **$0** Always Free (if within 2 OCPU / 12 GB / 200 GB) |
| Firebase FCM | **$0** Spark |
| Gmail SMTP | **$0** |
| Domain name | **~$10–15/year** (only paid piece most people need for HTTPS) |
| iOS | Not used |

---

## Stay free — checklist

1. Resize Ampere to **≤ 2 OCPU / 12 GB** total across the tenancy.  
2. Enable a **budget alert = $1** on OCI so trial/paid shapes can't surprise you.  
3. Don't expose Postgres (`5432`) to `0.0.0.0/0`.  
4. Put secrets only in `deploy/.env` (not git).  
5. After Postgres schema changes, recreate volume or add real Postgres migrations.  
6. Prefer HTTPS + one public port (Caddy) when you have a domain.
