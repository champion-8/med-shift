# Free-tier deploy (Oracle Always Free) — no iOS

MedShift on a single **Oracle Cloud Always Free** ARM VM: Postgres + API + Next.js.

Local Windows keep using **SQL Server Express** (`Database:Provider` default). Docker free path uses **Postgres** (SQL Server Docker is amd64-only; Ampere is ARM).

## Quick start (on the VM)

```bash
# Ubuntu 22.04/24.04 ARM
sudo apt update && sudo apt install -y docker.io docker-compose-v2 git
sudo usermod -aG docker $USER   # re-login

git clone <your-repo> medshift && cd medshift/deploy
cp .env.example .env
# edit .env — strong POSTGRES_PASSWORD + JWT_KEY + PUBLIC_API_URL

docker compose up -d --build
```

| Service | URL |
|---------|-----|
| API | `http://VM_IP:8080` |
| Web (Clinic/Admin) | `http://VM_IP:3000` |
| Postgres | `localhost:5432` (prefer not exposing publicly) |

Admin seed (same as local): `admin@medshift.local` / `Admin@12345`

### Flutter / Android (no iOS)

1. Set `baseUrl` in `mobile/lib/core/constants/app_constants.dart` to `http://VM_IP:8080` (or HTTPS domain).
2. Build APK: `flutter build apk --release`
3. Install on device / upload to Play internal testing when ready (Play Console has a one-time fee — not free forever for store listing).

### HTTPS (optional)

1. Point a domain A-record to the VM public IP.
2. Open Oracle Security List: TCP 80, 443 (and 22 for SSH).
3. Set `DOMAIN=your.domain` in `.env`, uncomment the `caddy` service in `docker-compose.yml`.
4. Set `PUBLIC_API_URL=https://your.domain` and rebuild `web`.

### Schema note (Postgres)

Free path uses `EnsureCreated` (SQL Server EF migrations are not portable).  
After model changes on Postgres: `docker compose down -v` then `up` again (wipes DB) **or** add a proper Postgres migration set later.

### Open ports on Oracle VCN

Ingress: **22**, **80/443** (if Caddy), **3000**, **8080** (or only 80/443 if everything is behind Caddy).

See [FREE_TIER.md](./FREE_TIER.md) for quota numbers.
