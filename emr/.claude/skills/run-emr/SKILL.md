---
name: run-emr
description: Run, screenshot, and interact with the ConcertoCare EMR web app. Use when asked to start the EMR, take a screenshot, verify a feature, test the UI, run the app, or check that a change works.
---

# run-emr — ConcertoCare EMR

ConcertoCare is a Next.js 14 frontend (port 3000) backed by a FastAPI/PostgreSQL API (port 8000).
In this container everything is driven by `driver.mjs` using Puppeteer + the bundled Chrome binary at
`/root/.cache/puppeteer/chrome/linux-149.0.7827.22/chrome-linux64/chrome`.
No Docker needed — PostgreSQL 16 runs directly on the host and the API runs via uvicorn.

## Prerequisites

These were confirmed installed in this container:

```bash
# Python deps — already present
pip3 install sqlalchemy aiosqlite   # if missing

# Node 22 — already at /opt/node22
# PostgreSQL 16 — already installed, cluster "main" port 5432

# Puppeteer — install globally (once per container)
npm install -g puppeteer
# Chrome binary auto-downloaded to ~/.cache/puppeteer/ — reuse if already there:
#   /root/.cache/puppeteer/chrome/linux-149.0.7827.22/chrome-linux64/chrome
```

The driver imports puppeteer from its absolute global path (`/opt/node22/lib/node_modules/puppeteer/...`).
If you reinstall Node or puppeteer moves, update the `import` line at the top of `driver.mjs`.

## Build

```bash
cd emr/apps/web
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1 npm run build
```

Build takes ~30 s. One known issue: `useSearchParams()` in any page component must be wrapped in `<Suspense>` or the build fails with a prerender error.

## Run (agent path — use this)

The driver lives at `.claude/skills/run-emr/driver.mjs`. All commands are run from `emr/apps/web/`:

```bash
cd emr/apps/web

# 1. Start infrastructure (do once; idempotent)
pg_ctlcluster 16 main start
DATABASE_URL=postgresql+asyncpg://emr:emr@localhost:5432/emr \
  REDIS_URL=redis://localhost:6379/0 \
  ANTHROPIC_API_KEY=dummy \
  SECRET_KEY=devsecretkey123 \
  uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload \
  --app-dir /home/user/omega2/emr/apps/api &> /tmp/api.log &

# Wait ~6 s, then confirm:
sleep 6 && curl -s http://localhost:8000/api/v1/auth/me

# 2. Start web server
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1 npm start &> /tmp/web.log &
sleep 4 && curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/login
# Expected: 200
```

### Driver commands

```bash
SKILL=../../.claude/skills/run-emr/driver.mjs   # relative to emr/apps/web/

# Verify API login works
node $SKILL login

# Screenshot all key pages (dashboard, patients, schedule, engagement)
mkdir -p /tmp/ss && node $SKILL smoke --out /tmp/ss

# Screenshot a specific page (must be logged in first)
node $SKILL screenshot --page /patients

# Open the first scheduled visit and screenshot it
node $SKILL visit

# Check patient count via API
node $SKILL patients
```

**Flags** (all optional):

| Flag | Default | Purpose |
|---|---|---|
| `--url` | `http://localhost:3000` | Web base URL |
| `--api` | `http://localhost:8000/api/v1` | API base URL |
| `--email` | `admin@concertocare.com` | Login email |
| `--pass` | `ConcertoDemo1!` | Login password |
| `--out` | `/tmp` | Screenshot output dir (must exist) |
| `--page` | — | URL suffix for `screenshot` command |

Screenshots are written to `--out/<command-name>.png`. The driver exits non-zero on any failure.

## Run (human path)

```bash
# Terminal 1 — API
cd emr/apps/api
DATABASE_URL=postgresql+asyncpg://emr:emr@localhost:5432/emr \
  REDIS_URL=redis://localhost:6379/0 ANTHROPIC_API_KEY=sk-ant-... \
  SECRET_KEY=devsecretkey123 \
  uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2 — Web
cd emr/apps/web
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1 npm run dev
# Open http://localhost:3000
```

Login: `admin@concertocare.com` / `ConcertoDemo1!`

## Seed demo data

If the database is empty:

```bash
cd emr/apps/api
DATABASE_URL=postgresql+asyncpg://emr:emr@localhost:5432/emr \
  REDIS_URL=redis://localhost:6379/0 ANTHROPIC_API_KEY=dummy \
  SECRET_KEY=devsecretkey123 \
  python -m app.db.seed_demo
```

This creates 100 patients across 9 cities, 9 providers, ~205 visits, HCC conditions. Idempotent (skips if ≥50 patients exist).

To create the org + admin only (faster, no patients):

```bash
cd emr/apps/api
DATABASE_URL=postgresql+asyncpg://emr:emr@localhost:5432/emr \
  REDIS_URL=redis://localhost:6379/0 ANTHROPIC_API_KEY=dummy \
  SECRET_KEY=devsecretkey123 python3 - << 'EOF'
import asyncio, app.models.organization, app.models.patient, app.models.user
import app.models.visit, app.models.condition, app.models.document
import app.models.engagement, app.models.territory, app.models.portal_message
import app.models.integration_key, app.models.lab_result, app.models.task
import app.models.workflow, app.models.notification, app.models.physician_order
import app.models.care_plan, app.models.oasis, app.models.plan_of_care
import app.models.eligibility, app.models.adt_event, app.models.audit_event
import app.models.visit_photo
from app.models.user import User, UserRole
from app.models.organization import Organization
from app.db.base import engine, Base
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from passlib.context import CryptContext

async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    async with AsyncSession(engine) as db:
        res = await db.execute(select(Organization).limit(1))
        org = res.scalar_one_or_none()
        if not org:
            org = Organization(name='ConcertoCare Demo', slug='concertocare', plan_tier='enterprise')
            db.add(org); await db.flush()
        res = await db.execute(select(User).where(User.email=='admin@concertocare.com'))
        admin = res.scalar_one_or_none()
        pwd = CryptContext(schemes=['bcrypt'], deprecated='auto').hash('ConcertoDemo1!')
        if not admin:
            db.add(User(organization_id=org.id, email='admin@concertocare.com',
                hashed_password=pwd, first_name='Admin', last_name='User',
                role=UserRole.admin, is_active=True))
        else:
            admin.hashed_password = pwd
        await db.commit()
        print('Done')

asyncio.run(seed())
EOF
```

## Gotchas

- **Model import order matters.** SQLAlchemy resolves forward references at mapper-configure time. Import order must be: `organization` → `patient` → `user` → `visit` → `condition` → everything else. Getting this wrong raises `InvalidRequestError: expression 'X' failed to locate a name`. The seed script above uses the correct order.

- **`useSearchParams()` needs Suspense.** Any Next.js page that calls `useSearchParams()` must wrap the calling component in `<Suspense>`. Without it, `npm run build` fails with a prerender error on that route. Fix: extract the hook into a child component, wrap the export default in `<Suspense fallback={...}><ChildComponent /></Suspense>`.

- **`DESC` ordering + 200-item limit cuts off future visits.** The visits API orders by `scheduled_at DESC`. If there are >200 past visits, all future scheduled visits are excluded from the response. The schedule page works around this by fetching `status=scheduled` and `status=in_progress` separately (upcoming visits always fit in 200 each).

- **Docker Hub rate limits block `postgres:16-alpine` pulls** in the cloud environment. Use the host's Postgres 16 (`pg_ctlcluster 16 main start`) instead of Docker for local testing.

- **ANTHROPIC_API_KEY=dummy is safe for local dev.** The AI chat and pre-visit brief features return 503 gracefully if the key is invalid. The rest of the app works normally. Set a real key to enable AI features.

- **`npm start` (production) vs `npm run dev`.** Production build (`next build` + `next start`) is ~5× faster for smoke testing. Dev server (`next dev`) enables hot reload but adds startup noise.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `GET /api/v1/auth/me → {"detail":"Not authenticated"}` | Expected when not logged in — API is up, this is correct behavior |
| API log: `Application startup complete.` but login fails 401 | Admin user not seeded. Run the seed snippet above |
| `sqlalchemy.exc.InvalidRequestError: expression 'X' failed to locate a name` | Missing model import in wrong order — add the missing model import before the one that references it |
| `useSearchParams() should be wrapped in a suspense boundary` | Wrap the component using `useSearchParams()` in `<Suspense>`. See Gotchas |
| Schedule page shows no visits | Visits exist but not on today's date — use the month calendar to navigate to a date with blue dots, or create a new visit |
| `pg_ctlcluster 16 main start` → `Removed stale pid file` then succeeds | Normal — stale PID from a prior crash, ignored safely |
| Chrome `--no-sandbox` required | Running as root in container. Always pass `--no-sandbox --disable-setuid-sandbox` |
| `ERR_MODULE_NOT_FOUND: Cannot find package 'puppeteer'` | ESM bare-specifier resolution ignores `NODE_PATH`. The driver uses an absolute path import. If the global puppeteer path changed (different Node version), update the `import` line in `driver.mjs` to match `npm root -g` + `/puppeteer/lib/puppeteer/puppeteer.js` |
