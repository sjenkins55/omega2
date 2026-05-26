# ConcertoCare EMR

AI-enabled home care EMR purpose-built for organizations like ConcertoCare.

## Modules

| Module | Description |
|--------|-------------|
| **Visits & Notes** | Clinicians dictate or type notes; AI auto-generates SOAP format, action items, and workflow triggers — no manual clicking |
| **AI Pre-Visit Brief** | Before every visit, Claude reviews the patient's full record and surfaces alerts, care gaps, focus areas, and medication review needs |
| **Data Ingestion / Faxes** | Faxes and uploaded documents are OCR'd and classified by AI — patient matched automatically, key findings extracted, workflows triggered |
| **Workflow Automation** | Power Automate-style builder — define trigger → conditions → steps (notify, create task, schedule visit, wait, branch) with zero manual intervention |
| **Engagement / Outreach** | AI-personalized SMS/email/phone outreach for reminders, care gaps, post-discharge follow-up |
| **Risk Stratification** | Claude Opus scores each patient with hospitalization/ED risk, contributing factors, and recommended visit frequency |

## Architecture

```
emr/
├── apps/
│   ├── api/          FastAPI backend (Python 3.12)
│   │   └── app/
│   │       ├── modules/
│   │       │   ├── ai_engine/     Claude API: briefs, SOAP structuring, risk scoring
│   │       │   ├── ingestion/     Fax/doc pipeline: OCR → classify → patient match
│   │       │   ├── workflows/     Event-driven DAG execution engine
│   │       │   └── engagement/    Outreach composition + dispatch
│   │       ├── models/            SQLAlchemy ORM (Patient, Visit, Document, Workflow, ...)
│   │       └── api/routes/        REST endpoints
│   └── web/          Next.js 14 frontend (TypeScript + Tailwind)
│       └── src/app/
│           ├── dashboard/
│           ├── patients/
│           ├── visits/
│           ├── ingestion/
│           ├── workflows/
│           └── engagement/
└── docker-compose.yml
```

## Quick Start

```bash
cp apps/api/.env.example apps/api/.env
# Fill in ANTHROPIC_API_KEY

docker compose up -d postgres redis
cd apps/api && pip install -r requirements.txt
uvicorn app.main:app --reload          # API at :8000
python -m app.db.seed                  # Seed workflows + demo patient

cd apps/web && npm install
npm run dev                            # Web at :3000
```

Or run everything:

```bash
ANTHROPIC_API_KEY=sk-ant-... docker compose up
```

## Key Design Principles

- **Zero-click workflows**: Every action triggered by an EMR event, not a human click
- **AI-first notes**: Clinicians speak or type naturally; AI handles structure and follow-up
- **Pre-visit intelligence**: Clinicians arrive briefed, not blank — AI surfaces what matters
- **Automated ingestion**: Faxes become structured data without staff touching them
- **Composable automations**: Workflows built in the UI like Power Automate, not hardcoded

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | Claude API key (required) |
| `DATABASE_URL` | PostgreSQL async URL |
| `REDIS_URL` | Redis for Celery task queue |
| `TWILIO_ACCOUNT_SID` / `TWILIO_AUTH_TOKEN` | Fax reception via Twilio |
| `AWS_*` / `S3_BUCKET` | Document storage |
